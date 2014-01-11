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




  /************************************/
  /* move samples from flash to radio */
  /************************************/
  
  event void LogRead.seekDone(error_t result)
  {  
    if (result == SUCCESS)
    {
      // update read cookie to be consistent with LogStorage
      offloadCookie = call LogRead.currentOffset();

      // fill offload buffer (reads multiple samples)
      call LogRead.read(offloadBuffer, FLASH_MAX_READ);
      printf("seek done: %lu\n\r", offloadCookie );
    } 
    else 
      // release semaphore so logReadWriteTask() can be posted again
      flashIsNotBusy = TRUE;

  }

  event void LogRead.readDone(void* buf_, storage_len_t len, error_t result)
  {
    uint8_t i;
    uint8_t sampleSize;
    uint8_t readCounter = 0;
    uint8_t * buffer = (uint8_t*) buf_;

    // release semaphore so logReadWriteTask() can be posted again
    if (result != SUCCESS)
    {
      flashIsNotBusy = TRUE;
      return;
    }      

    // find first record in buffer using type, length and crc
    for ( i = 0; i + SAMPLE_MAX_SIZE < len; i++ )
    {
      // checkMessage returns record length when match is found
      sampleSize = checkMessage(&(buffer[i]), TRUE);
      
      if (sampleSize > 0)
        break;      
    }      

    readCounter = i;

    // step through records in buffer
    while ( (sampleSize > 0) && ( (i + sampleSize) < len) )
    {
      uint8_t * payload;
      message_t * readMessagePointer;

      // only continue if there are free message buffers
      if (!call SendPool.empty())
      {
        readMessagePointer = call SendPool.get();    

        // copy record from buffer to message and queue for transmission
        payload = (uint8_t*) call Packet.getPayload(readMessagePointer, sampleSize);
        memcpy(payload, &(buffer[i]), sampleSize);      
        call SendQueue.enqueue(readMessagePointer);

        // update counters to skip to next record
        i += sampleSize;
        readCounter = i;

        // check if next record is valid (without crc check)
        sampleSize = checkMessage(&(buffer[i]), FALSE);
      }
      else
        break;
    } 
    
    // update read cookie to offset less-than-or-equal-to next unqueued record
    offloadCookie += readCounter;

    // start radio send task if not already started and the queue is not empty
    if ( sendIsNotBusy && !call SendQueue.empty() )
    {
      sendIsNotBusy = FALSE;
      post delaySendTask();
    }

    // continue reading from flash if not at end and there are available 
    // message buffers; otherwise repost logReadWriteTask to process write queue
    if ( !call SendPool.empty() && !(len < FLASH_MAX_READ) )
      call LogRead.seek(offloadCookie);
    else 
      post logReadWriteTask();

#ifdef DEBUG
    printf("cookies: %lu %lu %lu\n\r", offloadCookie, call LogRead.currentOffset(), call LogWrite.currentOffset() );      
    call Leds.led2Toggle();
#endif
  }

  /*
   * checks record validity by comparing the record length with record type and checking the CRC
   *
   * uint8_t* pl - buffer pointer
   * bool doCrc  - calculate record CRC
   *
   */
  uint8_t checkMessage(uint8_t* pl, bool doCrc)
  {
    sample_header_t * headerPointer = (sample_header_t*) pl;
    
    switch (headerPointer->type)
    {
      case TYPE_SAMPLE_BACON:
        {
          bool crcPassed;
          sample_bacon_t * localPointer = (sample_bacon_t*) pl;

          // calculate CRC or set as always TRUE if doCrc is FALSE        
          crcPassed = (doCrc) ? (localPointer->crc == call Crc.crc16(localPointer, sizeof(sample_bacon_t) - sizeof(uint16_t))) : TRUE;

          // check if the record length matches the record type
          if ( crcPassed && (headerPointer->length == sizeof(sample_bacon_t)) )
            return sizeof(sample_bacon_t);
        }

      case TYPE_SAMPLE_TOAST:
        {
          bool crcPassed;
          sample_toast_t * localPointer = (sample_toast_t*) pl;
        
          crcPassed = (doCrc) ? (localPointer->crc == call Crc.crc16(localPointer, sizeof(sample_toast_t) - sizeof(uint16_t))) : TRUE;

          if ( crcPassed && (headerPointer->length == sizeof(sample_toast_t)) )
            return sizeof(sample_toast_t);
        }
          
      case TYPE_SAMPLE_CLOCK:
        {
          bool crcPassed;
          sample_clock_t * localPointer = (sample_clock_t*) pl;
        
          crcPassed = (doCrc) ? (localPointer->crc == call Crc.crc16(localPointer, sizeof(sample_clock_t) - sizeof(uint16_t))) : TRUE;

          if ( crcPassed && (headerPointer->length == sizeof(sample_clock_t)) )
            return sizeof(sample_clock_t);
        }

      case TYPE_SAMPLE_STATUS:
        {
          bool crcPassed;
          sample_status_t * localPointer = (sample_status_t*) pl;
        
          crcPassed = (doCrc) ? (localPointer->crc == call Crc.crc16(localPointer, sizeof(sample_status_t) - sizeof(uint16_t))) : TRUE;

          if ( crcPassed && (headerPointer->length == sizeof(sample_status_t)) )
            return sizeof(sample_status_t);
        }

      default:
    }

    return 0;
  }


   
  event void LogWrite.eraseDone(error_t err) { }
  

  /***************************************************************************/
  /*                                                                         */
  /* Radio related                                                           */
  /*                                                                         */
  /***************************************************************************/

  /***********************************/
  /* Radio control                   */
  /***********************************/
  event void RadioControl.stopDone(error_t error) 
  { 
#ifdef DEBUG
    printf("radio off\n\r");
#endif
  }

  event void RadioControl.startDone(error_t error) 
  { 
#ifdef DEBUG
    printf("radio on\n\r");    
#endif
  }




  /***********************************/
  /* Periodic channel (send samples) */  
  /***********************************/

  // timer fires to initate offload
  event void OffloadTimer.fired()
  {
    post flashToSendPoolTask();
  }

  
  task void flashToSendPoolTask()
  {
    // read records from flash if message pool is not empty
    if ( !call SendPool.empty() )
    {
      fillSendPool = TRUE;

      if (flashIsNotBusy)
      {
        flashIsNotBusy = FALSE;
        post logReadWriteTask();
      }
    }
    // initiate send if the send queue is not empty 
    // called when previous send sequence failed and
    // the sendpool is empty
    else if ( sendIsNotBusy && !call SendQueue.empty() )
    {
      sendIsNotBusy = FALSE;
      post delaySendTask();
    }      
  }

  // use random delay to minimize collisions
  task void delaySendTask()
  {
    call DelayTimer.startOneShot(call Random.rand16() % 200);
  }
  
  event void DelayTimer.fired()
  {
    post sendTask();
  }

  task void sendTask()
  {
    message_t * sendMessagePointer;
    sample_header_t * headerPointer;
    error_t ret = FAIL;

    // task is called repeatedly to process send queue
    // terminates when queue is empty or send fails 
    if ( !call SendQueue.empty() )
    {
      sendMessagePointer = call SendQueue.head();
      call PacketAcknowledgements.requestAck(sendMessagePointer);

      headerPointer = (sample_header_t*) call Packet.getPayload(sendMessagePointer, sizeof(sample_header_t));

      // use record type to determine the number of bytes that needs to be send
      switch(headerPointer->type)
      {
        case TYPE_SAMPLE_BACON:
          ret = call PeriodicSend.send(gateway, sendMessagePointer, sizeof(sample_bacon_t));
          break;

        case TYPE_SAMPLE_TOAST:
          ret = call PeriodicSend.send(gateway, sendMessagePointer, sizeof(sample_toast_t));
          break;

        case TYPE_SAMPLE_CLOCK:
          ret = call PeriodicSend.send(gateway, sendMessagePointer, sizeof(sample_clock_t));
          break;

        case TYPE_SAMPLE_STATUS:
          ret = call PeriodicSend.send(gateway, sendMessagePointer, sizeof(sample_status_t));
          break;

        default:
          ret = call PeriodicSend.send(gateway, sendMessagePointer, call Packet.maxPayloadLength());
#ifdef DEBUG
          printf("unknown sample type: %d\n\r", headerPointer->type);    
#endif
      }
      
      // repost task if send fails (usually because of failed CCA)
      if (ret != SUCCESS)        
        post delaySendTask();


    } else 
      // release semaphore when send queue has been processed
      sendIsNotBusy = TRUE;
  }

  event void PeriodicSend.sendDone(message_t* msg_, error_t err) 
  {
    message_t * sendMessagePointer;

    if (err == SUCCESS)
    {
      sendMessagePointer = call SendQueue.dequeue();
      call SendPool.put(sendMessagePointer);
      
      post sendTask();
      post flashToSendPoolTask();
    }
    else 
      // release semaphore and retry at next offload period
      sendIsNotBusy = TRUE;
  }



  /***********************************/
  /* control channel                 */
  /***********************************/

  // control packets are used for measuring RSSI from Gateway to Leaf (through ack)
  // (RSSI is used to set the number of leds when a blink packet is received)
  // and to send alerts from Leaf to Gateway
  task void controlTask()
  {
    control_t * controlPointer;
    error_t ret = FAIL;

    controlPointer = (control_t*) call Packet.getPayload(&controlMessage, sizeof(control_t));

    controlPointer->length = sizeof(control_t);
    controlPointer->type = controlTaskParameter;
    controlPointer->source = TOS_NODE_ID;
    controlPointer->destination = gateway;
    
    call PacketAcknowledgements.requestAck(&controlMessage);

    ret = call ControlSend.send(gateway, &controlMessage, sizeof(control_t));
  
    // control packets have higher priority, retry immediately
    if (ret != SUCCESS)
      post controlTask();
  }
  
  
  event void ControlSend.sendDone(message_t* msg_, error_t err) 
  {
    int8_t rssi;
    
    if (err == SUCCESS)
    {
      switch(controlTaskParameter)
      {
        case TYPE_CONTROL_BLINK_PROBE:
                                      // use RSSI to set number of leds
                                      rssi = call Rf1aPacket.rssi(msg_);

                                      // -11 to -138
                                      if ( rssi > -60 )
                                        blinkTaskParameter = LEDS_LED0|LEDS_LED1|LEDS_LED2;
                                      else if ( rssi > -90)
                                        blinkTaskParameter = LEDS_LED0|LEDS_LED1;
                                      else
                                        blinkTaskParameter = LEDS_LED0;

                                      post blinkTask();

                                      break;
        case TYPE_CONTROL_PANIC:
        default:
      }
    }
  }
  
  // Gateway or Nfc application can send commands to Leaf
  // cookie     - resets the offload read cookie to address in field32
  // clock      - time sync packet containing counter and real-time clock
  // blink      - blink immediately
  // blink_link - only blink if connected to Gateway
  event message_t* ControlReceive.receive(message_t* msg_, void* pl, uint8_t len)
  { 
    uint8_t i;
    control_t * controlPtr = (control_t*) pl;
        
    switch (controlPtr->type) 
    {
      case TYPE_CONTROL_SET_COOKIE:
                              // check if new read cookie is valid before use
                              if ( controlPtr->field32 <= call LogWrite.currentOffset() )
                                offloadCookie = controlPtr->field32;
                              break;

      case TYPE_CONTROL_CLOCK:
                              // read remote clock counter, boot counter, and real-time clock
                              remoteSource = controlPtr->source;
                              remoteTime = controlPtr->field32;
                              remoteBoot = controlPtr->field8;

                              for ( i = 0; i < 7; i++ )
                                remoteRtc[i] = controlPtr->array7[i];
                                
                              post clockSampleTask();
                              break;

      case TYPE_CONTROL_BLINK:
                              // blink immediately
                              blinkTaskParameter = LEDS_LED0|LEDS_LED1|LEDS_LED2;
                              post blinkTask();
                              break;
                              
      case TYPE_CONTROL_BLINK_LINK:
                              // blink if connected to Gateway
                              blinkTaskParameter = LEDS_LED2;
                              post blinkTask();
                              
                              controlTaskParameter = TYPE_CONTROL_BLINK_PROBE;
                              post controlTask();
                              break;

      default:
                              printf("unknown control type\n\r");
                              break;
    }                              

    return msg_;
  }
