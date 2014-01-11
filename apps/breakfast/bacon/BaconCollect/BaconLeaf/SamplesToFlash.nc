/*
 * Copyright (c) 2014 Johns Hopkins University.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
*/

  /***************************************************************************/
  /* Sampling                                                                */
  /***************************************************************************/

  // all data that needs to be transferred reliably to the Gateway is 
  // treated as samples and are stored in the flash as records.
  //
  // bacon  - onboard sensors (light, temp, battery)
  // toast  - all 8 toast channels and the VCC
  // clock  - the contents of any received clock type control packets
  // status - radio duty-cycle, queue usages, etc.

  /************************************/
  /* Bacon sampling                   */
  /************************************/

  event void BaconSampleTimer.fired() 
  {    
    post baconSampleTask();        
  }

  task void baconSampleTask()
  {  
    sample_header_t * headerPointer;

    if (!call WritePool.empty())
    {
      // allocate buffer
      baconSamplePointer = (sample_bacon_t*) call WritePool.get();      
 
      // fill header
      headerPointer = &(baconSamplePointer->info); 
      headerPointer->length = sizeof(sample_bacon_t);
      headerPointer->type = TYPE_SAMPLE_BACON;
      headerPointer->source = TOS_NODE_ID;
      headerPointer->boot = boot_counter;

      // start sampling 
      call LightControl.start();
      call TempControl.start();
      call BatteryControl.start();
    }
    else 
    {
      // send panic packet if buffer allocation fails
      controlTaskParameter = TYPE_CONTROL_PANIC;
      post controlTask();
    }
  }
  

  event void LightControl.stopDone(error_t error) { }
  event void LightControl.startDone(error_t error) 
  { 
    call Apds9007.read(); 
  }

  event void Apds9007.readDone(error_t error, uint16_t val) 
  {
    call Mcp9700.read();
    
    baconSamplePointer->light = val;    
  }


  event void TempControl.stopDone(error_t error) { }
  event void TempControl.startDone(error_t error) { }

  event void Mcp9700.readDone(error_t error, uint16_t val) 
  {
    call BatteryVoltage.read();

    baconSamplePointer->temp = val;        
  }


  event void BatteryControl.stopDone(error_t error) { }
  event void BatteryControl.startDone(error_t error) { }

  event void BatteryVoltage.readDone(error_t error, uint16_t val) 
  {    
    baconSamplePointer->battery = val;    

    call LightControl.stop();
    call TempControl.stop();
    call BatteryControl.stop();

    // get local timestamp
    (baconSamplePointer->info).time = call WDTResetTimer.getNow();    
        
    // put buffer in flash write queue
    call WriteQueue.enqueue((sample_t*)baconSamplePointer);    

    // post logReadWriteTask if not already posted and flash is busy 
    if (flashIsNotBusy)
    {
      flashIsNotBusy = FALSE;
      post logReadWriteTask();
    }
  }

  /***********************************/
  /* Toast sampling                  */
  /***********************************/

  event void ToastSampleTimer.fired()
  {
    // only proceed if toast is attached
    if (toastCounter > 0)
    {
      currentToast = 0;

      post toastSampleTask();
    }
  }

  task void toastSampleTask()
  {  
    sample_header_t * headerPointer;

    if (!call WritePool.empty())
    {
      // allocate buffer 
      toastSamplePointer = call WritePool.get();        
      
      // fill header
      headerPointer = &(toastSamplePointer->info);      
      headerPointer->length = sizeof(sample_toast_t);
      headerPointer->type = TYPE_SAMPLE_TOAST;
      headerPointer->source = TOS_NODE_ID;
      headerPointer->boot = boot_counter;
        
      // start sampling 
      call I2CADCReaderMaster.sample(toastAddress[currentToast].address, i2cMessagePtr);
    }
    else 
    {
      // send panic packet if buffer allocation fails
      controlTaskParameter = TYPE_CONTROL_PANIC;
      post controlTask();
    }
  }


  event i2c_message_t* I2CADCReaderMaster.sampleDone(error_t error, uint16_t slaveAddr,
      i2c_message_t* cmdMsg, i2c_message_t* responseMsg, 
      adc_response_t* response)
  {
    uint8_t i;
    adc_sample_t cur;

    // get local time stamp
    (toastSamplePointer->info).time = call WDTResetTimer.getNow();    

    if (response != NULL)
    {
      // use low id as unique id
      toastSamplePointer->id = toastAddress[currentToast].id_low;

      // copy samples to buffer 
      for (i = 0; i < ADC_NUM_CHANNELS - 1; i++)
      {
        cur = response->samples[i];

        if (cur.inputChannel == INPUT_CHANNEL_NONE)
          break;

        toastSamplePointer->sample[i] = cur.sample;
      }
    }

    // put buffer in flash write queue
    call WriteQueue.enqueue((sample_t*)toastSamplePointer);

    // post logReadWriteTask if not already posted and flash is busy 
    if (flashIsNotBusy)
    {
      flashIsNotBusy = FALSE;
      post logReadWriteTask();
    }
    
    // sample next toast board 
    ++currentToast;
    if (currentToast < toastCounter)
    {
      post toastSampleTask();
    }
      
    return responseMsg;
  }


  /***********************************/
  /* clock sampling (phoenix TS)     */
  /***********************************/

  task void clockSampleTask()
  {
    uint8_t i;
    sample_header_t * headerPointer;
    sample_clock_t * clockSamplePointer;

    if (!call WritePool.empty())
    {
      // allocate buffer 
      clockSamplePointer = (sample_clock_t*) call WritePool.get();
          
      // fill header
      headerPointer = &(clockSamplePointer->info); 
      headerPointer->length = sizeof(sample_clock_t);
      headerPointer->type = TYPE_SAMPLE_CLOCK;
      headerPointer->source = TOS_NODE_ID;
      headerPointer->boot = boot_counter;

      headerPointer->time = call WDTResetTimer.getNow();    

      // remote values received in clock type control packet
      clockSamplePointer->reference = remoteSource;
      clockSamplePointer->boot = remoteBoot;
      clockSamplePointer->time = remoteTime;

      for ( i = 0; i < 7; i++ )
        clockSamplePointer->rtc[i] = remoteRtc[i];

      // put buffer in flash write queue
      call WriteQueue.enqueue((sample_t*)clockSamplePointer);

      // post logReadWriteTask if not already posted and flash is busy 
      if (flashIsNotBusy)
      {
        flashIsNotBusy = FALSE;        
        post logReadWriteTask();
      }
    }
    else 
    {
      // send panic packet if buffer allocation fails
      controlTaskParameter = TYPE_CONTROL_PANIC;
      post controlTask();
    }
  }


  /************************************/
  /* Status sampling                  */
  /************************************/

  event void StatusSampleTimer.fired() 
  {    
    post statusSampleTask();        
  }

  task void statusSampleTask()
  {
    sample_header_t * headerPointer;
    sample_status_t * statusSamplePointer;

    if (!call WritePool.empty())
    {
      // allocate buffer
      statusSamplePointer = (sample_status_t*) call WritePool.get();
          
      // fill header
      headerPointer = &(statusSamplePointer->info);
      headerPointer->length = sizeof(sample_status_t);
      headerPointer->type = TYPE_SAMPLE_STATUS;
      headerPointer->source = TOS_NODE_ID;
      headerPointer->boot = boot_counter;

      headerPointer->time = call WDTResetTimer.getNow();    

      // status information
      statusSamplePointer->writeQueue = call WriteQueue.size();
      statusSamplePointer->sendQueue = call SendQueue.size();
      statusSamplePointer->radioOnTime = radioOnTime;
      statusSamplePointer->radioOffTime = radioOffTime;
  
      // reset radio counters
      radioOnTime = 0;
      radioOffTime = 0;

      // put buffer in flash write queue
      call WriteQueue.enqueue((sample_t*)statusSamplePointer);

      // post logReadWriteTask if not already posted and flash is busy 
      if (flashIsNotBusy)
      {
        flashIsNotBusy = FALSE;        
        post logReadWriteTask();
      }
    }
    else 
    {
      // send panic packet if buffer allocation fails
      controlTaskParameter = TYPE_CONTROL_PANIC;
      post controlTask();
    }
  }

  // use lower layer radio control to keep track of radio duty-cycle 
  event void PhysicalControl.stopDone(error_t error) 
  { 
    uint32_t currentTime;

    currentTime = call WDTResetTimer.getNow();    
    radioOnTime += currentTime - lastTime;    
    lastTime = currentTime;

  }

  event void PhysicalControl.startDone(error_t error) 
  { 
    uint32_t currentTime;

    currentTime = call WDTResetTimer.getNow();    
    radioOffTime += currentTime - lastTime;    
    lastTime = currentTime;
  }


  /***************************************************************************/
  /* Toast Board                                                             */
  /***************************************************************************/

  /***********************************/
  /* Toast ADC congifuration         */
  /***********************************/

  task void initChannelsTask() 
  {
    uint8_t channelIndex;
    
    // use same for all channels
    uint32_t sampleDelay = 256;

    adc_reader_pkt_t* cmd = call I2CADCReaderMaster.getSettings(i2cMessagePtr);

    for ( channelIndex = 0; channelIndex < ADC_NUM_CHANNELS - 1; channelIndex++)
    {  
      cmd->cfg[channelIndex].delayMS = sampleDelay;
      cmd->cfg[channelIndex].config.inch = channelIndex;
      
      cmd->cfg[channelIndex].config.sref = REFERENCE_VREFplus_AVss;
      cmd->cfg[channelIndex].config.ref2_5v = REFVOLT_LEVEL_2_5;
      cmd->cfg[channelIndex].config.adc12ssel = SHT_SOURCE_ADC12OSC;
      cmd->cfg[channelIndex].config.adc12div = SHT_CLOCK_DIV_1;    
      cmd->cfg[channelIndex].config.sht = SAMPLE_HOLD_16_CYCLES;
      cmd->cfg[channelIndex].samplePeriod = 0;
      cmd->cfg[channelIndex].config.sampcon_ssel = SAMPCON_SOURCE_ACLK;
      cmd->cfg[channelIndex].config.sampcon_id = SAMPCON_CLOCK_DIV_1;
    }

    cmd->cfg[ADC_NUM_CHANNELS - 2].config.inch = 0x0B;
    cmd->cfg[ADC_NUM_CHANNELS - 1].config.inch = INPUT_CHANNEL_NONE;
  }

  /***********************************/
  /* Toast discovery                 */
  /***********************************/

  task void toastDiscoveryTask()
  {
#ifdef DEBUG
    printf("Start toast discovery\n\r");
#endif

    toastCounter = 0;

    call I2CDiscoverer.startDiscovery(TRUE, 0x40);
  }

  event uint16_t I2CDiscoverer.getLocalAddr()
  {
    return TOS_NODE_ID & 0x7F;
  }

  event discoverer_register_union_t* I2CDiscoverer.discovered(discoverer_register_union_t* discovery)
  {
    uint32_t id;

    // associate local address with toast unique address
    
    toastAddress[toastCounter].address = discovery->val.localAddr;

#ifdef DEBUG
    printf("Assigned %x to ", discovery->val.localAddr);
#endif

    id = discovery->val.globalAddr[0];
    id = (id << 8) | discovery->val.globalAddr[1];
    id = (id << 8) | discovery->val.globalAddr[2];
    id = (id << 8) | discovery->val.globalAddr[3];
    
    toastAddress[toastCounter].id_high = id;    

#ifdef DEBUG
    printf(" %lu ", id);
#endif

    id = discovery->val.globalAddr[4];
    id = (id << 8) | discovery->val.globalAddr[5];
    id = (id << 8) | discovery->val.globalAddr[6];
    id = (id << 8) | discovery->val.globalAddr[7];
    
    toastAddress[toastCounter].id_low = id;    

#ifdef DEBUG
    printf(" %lu ", id);
    printf("\n\r");
#endif

    ++toastCounter;

    return discovery;
  }

  event void I2CDiscoverer.discoveryDone(error_t error)
  {
#ifdef DEBUG
    printf("%s: %s\n\r", __FUNCTION__, decodeError(error));
#endif
  }


  /***************************************************************************/
  /* Flash                                                                   */
  /***************************************************************************/

  /***********************************/
  /* samples from memory to flash    */
  /***********************************/

  // main flash function 
  // 
  // acts as mutex for read/write
  // is called repeatedly to process write queue and fill send queue
  //
  task void logReadWriteTask()
  {
    sample_header_t * headerPointer;
    sample_bacon_t * baconWritePointer;
    sample_toast_t * toastWritePointer;
    sample_clock_t * clockWritePointer;
    sample_status_t * statusWritePointer;

    if (!call WriteQueue.empty())
    {
      // get queue head but leave in queue until successful append
      headerPointer = (sample_header_t*) call WriteQueue.head();  

      // store the flash write address; useful for Gateway to offload older records
      headerPointer->flash = call LogWrite.currentOffset();

      switch(headerPointer->type)
      {
        case TYPE_SAMPLE_BACON:
            baconWritePointer = (sample_bacon_t*) headerPointer;
            
            // calculate CRC
            baconWritePointer->crc = call Crc.crc16(baconWritePointer, sizeof(sample_bacon_t) - sizeof(uint16_t));

            // append to flash
            call LogWrite.append(baconWritePointer, sizeof(sample_bacon_t));
            break;
          
        case TYPE_SAMPLE_TOAST:
            toastWritePointer = (sample_toast_t*) headerPointer;
            toastWritePointer->crc = call Crc.crc16(toastWritePointer, sizeof(sample_toast_t) - sizeof(uint16_t));

            call LogWrite.append(toastWritePointer, sizeof(sample_toast_t));
            break;
          
        case TYPE_SAMPLE_CLOCK:
            clockWritePointer = (sample_clock_t*) headerPointer;
            clockWritePointer->crc = call Crc.crc16(clockWritePointer, sizeof(sample_clock_t) - sizeof(uint16_t));

            call LogWrite.append(clockWritePointer, sizeof(sample_clock_t));
            break;

        case TYPE_SAMPLE_STATUS:
            statusWritePointer = (sample_status_t*) headerPointer;
            statusWritePointer->crc = call Crc.crc16(statusWritePointer, sizeof(sample_status_t) - sizeof(uint16_t));

            call LogWrite.append(statusWritePointer, sizeof(sample_status_t));
            break;
          
        default:
#ifdef DEBUG        
            printf("unknown sample type: %d\n\r", headerPointer->type);    
#endif
      }

#ifdef DEBUG
    printf("cookies: %lu %lu %lu\n\r", offloadCookie, call LogRead.currentOffset(), call LogWrite.currentOffset() );      
    call Leds.led1Toggle();
#endif
        
    }
    // read records and queue them up for transmission
    else if ( fillSendPool )
    {
      fillSendPool = FALSE;

      // but only if send message buffer is available and flash contains unqueued records
      if ( !call SendPool.empty() && (call LogRead.currentOffset() != call LogWrite.currentOffset()) )
        call LogRead.seek(offloadCookie);
      else
        // release flash semaphore
        flashIsNotBusy = TRUE;
    }
    else
      // release flash semaphore
      flashIsNotBusy = TRUE;

  }

  event void LogWrite.appendDone(void* buf_, storage_len_t len, bool recordsLost, error_t error)
  {
    sample_t * writeSamplePointer;

    if (error == SUCCESS)    
    {
      // return buffer to pool
      writeSamplePointer = call WriteQueue.dequeue();
      call WritePool.put(writeSamplePointer);

    }

    // process next buffer in queue
    post logReadWriteTask();
  }
