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

#include <stdio.h>
#include "decodeError.h"
#include "baconCollect.h"
#include "I2CADCReader.h"

module RouterP{
  uses interface Boot;
  uses interface Leds;
  uses interface Random;
  uses interface Crc;
  uses interface LogRead;
  uses interface LogWrite;
  
  /* Timers */  
  uses interface Timer<TMilli> as StatusTimer;
  uses interface Timer<TMilli> as WDTResetTimer;
  uses interface Timer<TMilli> as LedsTimer;
  uses interface Timer<TMilli> as ClockTimer;

  /* UART */
  uses interface StdControl as SerialControl;
  uses interface UartStream;

  /* Radio */
  uses interface SplitControl as RadioControl;
  uses interface Receive as PeriodicReceive;
  uses interface AMSend as ControlSend;
  uses interface Receive as ControlReceive;
  uses interface Receive as MasterControlReceive;

  uses interface Packet;
  uses interface AMPacket;
  uses interface Rf1aPacket;
 
  uses interface HplMsp430GeneralIO as CS;
  uses interface HplMsp430GeneralIO as CD;
  uses interface HplMsp430GeneralIO as FlashEnable;

  uses interface PacketAcknowledgements;
  uses interface SplitControl as PhysicalControl;
  
  uses interface Pool<message_t>;
  uses interface Queue<message_t*>;
  
} implementation {

  void printMessage(void*);

  uint8_t __attribute__ ((section(".noinit"))) boot_counter;

  control_t * controlPointer;
  
  message_t controlMessage;

  /*************************/
  uint8_t ledsGet;
  uint16_t blinkNodeID;
  /*************************/
  uint8_t remoteRtc[7];
  task void clockTask();
  

  /*************************/
  /* status messages       */  
  uint32_t radioOnTime;
  uint32_t radioOffTime;
  uint32_t lastTime;
  
  /*************************/
  /* flash read            */  
  uint32_t flashCookie;
  uint8_t flashBuffer[256];
  /*************************/
  event void Boot.booted()
  {
    call FlashEnable.set();
    call FlashEnable.makeOutput();
    call FlashEnable.selectIOFunc();
        
    call SerialControl.start();
    call WDTResetTimer.startPeriodic(512);
    
    //set WDT to reset at 1 second
    WDTCTL = WDT_ARST_1000;

    /* boot sequence continues in syncDone */
    call LogWrite.sync();
  }

  /***************************************************************************/
  /* Flash                                                                   */
  /***************************************************************************/

  event void LogWrite.syncDone(error_t error) 
  { 
    uint16_t reset_vector = SYSRSTIV;
    if (reset_vector == 0x04)
      boot_counter = 0;
    else
      ++boot_counter;

    flashCookie = call LogWrite.currentOffset();

    controlPointer = (control_t*) call Packet.getPayload(&controlMessage, sizeof(control_t));

    printf("root: %d %X\n\r", boot_counter, reset_vector);

    call RadioControl.start();
    call ClockTimer.startPeriodic(ROUTER_CLOCK_INTERVAL);
    call StatusTimer.startPeriodic(ROUTER_STATUS_INTERVAL);

    /* flash leds to signal successful boot */
    ledsGet = LEDS_LED0|LEDS_LED1|LEDS_LED2;
    call Leds.set(LEDS_LED0|LEDS_LED1|LEDS_LED2);
    call LedsTimer.startOneShot(512);
  }

  message_t * writePointer;
  bool writeNotInProgress = TRUE;
  
  task void logWriteTask()
  {
    void* payload;
    uint8_t length;
    
    if (!call Queue.empty())
    {
      writePointer = call Queue.dequeue();  

      length = call Packet.payloadLength(writePointer);
      payload = call Packet.getPayload(writePointer, length);
      
      call LogWrite.append(payload, length);    
    }
    else
      writeNotInProgress = TRUE;
  }

  event void LogWrite.appendDone(void* buf_, storage_len_t len, bool recordsLost, error_t error)
  {
    call Pool.put(writePointer);
    post logWriteTask();
  }

  event void LogWrite.eraseDone(error_t err)
  {

  }
  
  event void LogRead.seekDone(error_t err)
  {
    uint32_t cookie = call LogRead.currentOffset();
    
    printf("seek done: %X%X\n\r", (uint16_t)(cookie >> 16), (uint16_t)(cookie & 0x0000FFFF));
  }

  event void LogRead.readDone(void* buf_, storage_len_t len, error_t err)
  {
    uint16_t i;
    uint8_t * buffer = (uint8_t*) buf_;
    
    for (i = 0; i < len; i++)
      printf("%02X", buffer[i]);
    
  }

  /***************************************************************************/
  /* Timers                                                                  */
  /***************************************************************************/
    
  event void StatusTimer.fired()
  {
    message_t * statusMessage;
    uint32_t time;
    sample_status_t * statusPointer;
    sample_header_t * headerPointer;
    
    if (!call Pool.empty())
    {
      time = call StatusTimer.getNow();
    
      statusMessage = call Pool.get();
      call Packet.setPayloadLength(statusMessage, sizeof(sample_status_t));

      headerPointer = (sample_header_t*) call Packet.getPayload(statusMessage, sizeof(sample_status_t));
      headerPointer->length = sizeof(sample_status_t);
      headerPointer->type = TYPE_LOCAL_STATUS;
      headerPointer->source = TOS_NODE_ID;
      headerPointer->boot = boot_counter;
      headerPointer->time = time;
      headerPointer->flash = call LogWrite.currentOffset();

      statusPointer = (sample_status_t*) headerPointer;
      statusPointer->radioOnTime = radioOnTime;
      statusPointer->radioOffTime = radioOffTime;
      statusPointer->crc = call Crc.crc16(statusPointer, sizeof(sample_status_t) - sizeof(uint16_t));
      
      call Queue.enqueue(statusMessage);

      if (writeNotInProgress)
      {
        writeNotInProgress = FALSE;
        post logWriteTask();
      }
    }
    
    
    printf("%u ", TYPE_LOCAL_STATUS);
    printf("%lu %u ", time, boot_counter);        
    printf("%lu %lu", radioOnTime, radioOffTime);
    printf("\n\r");
    
    radioOnTime = 0;
    radioOffTime = 0;
  }

  event void WDTResetTimer.fired() {
    //re-up the wdt
    WDTCTL =  WDT_ARST_1000;
  }

  event void ClockTimer.fired() 
  {
    uint8_t i;
    
    // no RTC received, reset to zero
    for ( i = 0; i < 7; i++ )
    {
      remoteRtc[i] = 0;
    }

    post clockTask();        
  }

  event void LedsTimer.fired() 
  {
    if (ledsGet & LEDS_LED2)
    {
      ledsGet &= ~LEDS_LED2;
      call Leds.led2Off();
      call LedsTimer.startOneShot(256);
    }
    else if (ledsGet & LEDS_LED1)
    {
      ledsGet &= ~LEDS_LED1;
      call Leds.led1Off();
      call LedsTimer.startOneShot(256);
    }
    else 
    {
      ledsGet = 0;
      call Leds.led0Off();
    }  
  }

  /***************************************************************************/
  /* Radio                                                                   */
  /***************************************************************************/
  event void RadioControl.stopDone(error_t error) 
  { 
    printf("radio off\n\r");
  }

  event void RadioControl.startDone(error_t error) 
  { 
    printf("radio on\n\r");    
  }

  event void PhysicalControl.stopDone(error_t error) 
  { 
    uint32_t currentTime;

    currentTime = call StatusTimer.getNow();    
    radioOnTime += currentTime - lastTime;    
    lastTime = currentTime;

  }

  event void PhysicalControl.startDone(error_t error) 
  { 
    uint32_t currentTime;

    currentTime = call StatusTimer.getNow();    
    radioOffTime += currentTime - lastTime;    
    lastTime = currentTime;
  }

  event message_t* PeriodicReceive.receive(message_t* msg_, void* pl, uint8_t len)
  { 
    uint8_t i;
//    for (i=0; i< sizeof(message_t); i++){
//      printf("%02X", ((uint8_t*)msg_)[i]);
//    }
//    printf("\r\n");
//
//    for (i=0; i< len; i++){
//      printf("%02X", ((uint8_t*)pl)[i]);
//    }
//    printf("\r\n");
//    printf("rp: %p calc: %p\r\n", pl, 
//      call Packet.getPayload(msg_, sizeof(sample_status_t)));
    printMessage(pl);

    if (!call Pool.empty())
    {
      call Queue.enqueue(msg_);

      if (writeNotInProgress)
      {
        writeNotInProgress = FALSE;
        post logWriteTask();
      }
      
      return call Pool.get();
    }
    else
      return msg_;
  }
  
  void printMessage(void* pl)
  {
    sample_header_t * headerPointer;
    uint32_t rxTime;
    uint8_t i;

    rxTime = call StatusTimer.getNow();

    headerPointer = (sample_header_t*) pl;

    printf("%3d ", headerPointer->source); 
    printf("%d ", headerPointer->type); 

    printf("%04X", (uint16_t) (headerPointer->flash >> 16));
    printf("%04X ", (uint16_t) (headerPointer->flash & 0x0000FFFF));

    printf("%9lu ", rxTime);

    printf("%3u ", headerPointer->boot); 
    printf("%9lu ", headerPointer->time);

    if (headerPointer->type == TYPE_SAMPLE_BACON)
    {
      sample_bacon_t * localPointer = (sample_bacon_t*) pl;
      printf("%5u ", localPointer->battery);
      printf("%5u ", localPointer->light);
      printf("%5u ", localPointer->temp);
      printf("%04X ", localPointer->crc);
      printf("%04X", call Crc.crc16(localPointer, sizeof(sample_bacon_t) - sizeof(uint16_t)));
      printf("\n\r");
    }
    else if (headerPointer->type == TYPE_SAMPLE_TOAST)
    {
      sample_toast_t * localPointer = (sample_toast_t*) pl;

      for (i = 0; i < ADC_NUM_CHANNELS - 1; i++)
      {
        printf("%5u ", localPointer->sample[i]);
      }
      printf("%04X", (uint16_t) (localPointer->id >> 16));      
      printf("%04X ", (uint16_t) (localPointer->id & 0x0000FFFF));      
      printf("%04X ", localPointer->crc);
      printf("%04X", call Crc.crc16(localPointer, sizeof(sample_toast_t) - sizeof(uint16_t)));
      printf("\n\r");
    }
    else if (headerPointer->type == TYPE_SAMPLE_CLOCK)
    {
      sample_clock_t * localPointer = (sample_clock_t*) pl;

      printf("%5u ", localPointer->reference);
      printf("%3u ", localPointer->boot);
      printf("%9lu ", localPointer->time);
      for (i = 0; i < 7; i++)
        printf("%2u ", localPointer->rtc[i]);        
      printf(" %04X ", localPointer->crc);
      printf("%04X", call Crc.crc16(localPointer, sizeof(sample_clock_t) - sizeof(uint16_t)));
      printf("\n\r");
    }
    else if (headerPointer->type == TYPE_SAMPLE_STATUS)
    {
      sample_status_t * localPointer = (sample_status_t*) pl;

      printf("%3u ", localPointer->writeQueue);
      printf("%3u ", localPointer->sendQueue);
      printf("%9lu ", localPointer->radioOnTime);
      printf("%9lu ", localPointer->radioOffTime);
      printf("%04X ", localPointer->crc);
      printf("%04X", call Crc.crc16(localPointer, sizeof(sample_status_t) - sizeof(uint16_t)));
      printf("\n\r");
    }
    else
      printf("unknown sample type: %d\n\r", headerPointer->type);

  }

  /***************************************************************************/

  uint32_t offloadAddress = SEEK_BEGINNING;
  uint16_t readNode = 0x0001;

  task void setOffloadCookieTask()
  {
    error_t ret;
    
    controlPointer->length = sizeof(control_t);
    controlPointer->type = TYPE_CONTROL_SET_COOKIE;
    controlPointer->destination = readNode;
    controlPointer->field32 = offloadAddress;

    printf("read: %lu\n\r", offloadAddress);

    ret = call ControlSend.send(readNode, &controlMessage, sizeof(control_t));
    
    if (ret != SUCCESS)
      post setOffloadCookieTask();
  }



  /* Control - Blink LEDS on node NODEID */  
  task void sendBlinkTask()
  {
    error_t ret;
    
    controlPointer->length = sizeof(control_t);
    controlPointer->type = TYPE_CONTROL_BLINK;
    controlPointer->destination = blinkNodeID;

    ret = call ControlSend.send(blinkNodeID, &controlMessage, sizeof(control_t));
    
    if (ret != SUCCESS)
      post sendBlinkTask();
  }

  /* Control - broadcast local time and newest RTC */
  task void clockTask()
  {
    uint8_t i;
    error_t ret;
    
    controlPointer->length = sizeof(control_t);
    controlPointer->type = TYPE_CONTROL_CLOCK;
    controlPointer->source = TOS_NODE_ID;
    controlPointer->destination = AM_BROADCAST_ADDR;
    controlPointer->field8 = boot_counter;
    controlPointer->field32 = call StatusTimer.getNow();
    
    for ( i = 0; i < 7; i++ )
      controlPointer->array7[i] = remoteRtc[i];

    ret = call ControlSend.send(AM_BROADCAST_ADDR, &controlMessage, sizeof(control_t));
    
    if (ret != SUCCESS)
      post clockTask();
  }
    

  event void ControlSend.sendDone(message_t* msg_, error_t err) 
  {
    if (err != SUCCESS)
      printf("send failed\n\r");
  }

  event message_t* ControlReceive.receive(message_t* msg_, void* pl, uint8_t len)
  { 
    uint8_t i;
    int8_t rssi;
    
    control_t * controlPtr = (control_t*) pl;

//    printf("%u %9lu ", controlPtr->type, call StatusTimer.getNow());

        
    switch (controlPtr->type) 
    {
      case TYPE_CONTROL_BLINK_PROBE:
                              /* ignore */
                              break;
                              
      case TYPE_CONTROL_BLINK_LINK:
                              /* blink local leds */
                              rssi = call Rf1aPacket.rssi(msg_);
                              
                              // -11 to -138
                              if ( rssi > -60 )
                              {
                                ledsGet = LEDS_LED0|LEDS_LED1|LEDS_LED2;
                                call Leds.set(LEDS_LED0|LEDS_LED1|LEDS_LED2);
                              }
                              else if ( rssi > -90)
                              {
                                ledsGet = LEDS_LED0|LEDS_LED1;
                                call Leds.set(LEDS_LED0|LEDS_LED1);
                              }
                              else
                              {
                                ledsGet = LEDS_LED0;
                                call Leds.set(LEDS_LED0);
                              }
                                
                              call LedsTimer.startOneShot(512);

                              /* resend blink command */                              
                              blinkNodeID = controlPtr->destination;
                              post sendBlinkTask();
                              
                              break;

      case TYPE_CONTROL_CLOCK:
                              printf("%u %9lu ", controlPtr->source, call StatusTimer.getNow());
                              printf("%u %lu ", controlPtr->field8, controlPtr->field32);

                              for ( i = 0; i < 7; i++ )
                              {
                                remoteRtc[i] = controlPtr->array7[i];
                                printf("%2u ", remoteRtc[i]);
                              }
                              
                              printf("\n\r");

                              call ClockTimer.startPeriodic(ROUTER_CLOCK_INTERVAL);
                              post clockTask();

                              break;

      case TYPE_CONTROL_PANIC:
                              printf("%u %9lu ", controlPtr->source, call StatusTimer.getNow());
                              printf("panic\n\r");
                              break;
                              
      default:
                              printf("unknown control type\n\r");
                              break;
    }                              

    return msg_;
  }
  


  event message_t* MasterControlReceive.receive(message_t* msg_, void* pl, uint8_t len)
  { 

    return msg_;
  }
  
  /***************************************************************************/
  /* UART                                                                    */
  /***************************************************************************/

  norace uint8_t uartByte;
  task void uartTask();

  async event void UartStream.receivedByte(uint8_t byte) {

    uartByte = byte;
    
    post uartTask();
  }
  
  task void uartTask()
  {
  
    switch ( uartByte ) {
   
      case '0':
        call RadioControl.stop();
        break;
      case '1':
        call RadioControl.start();
        break;
   
      case 't':
        remoteRtc[0] = 0; // seconds
        remoteRtc[1] = 0x35; // minutes
        remoteRtc[2] = 0x21; // hour
        remoteRtc[3] = 0x01; // day of week
        remoteRtc[4] = 0x21; // date
        remoteRtc[5] = 0x05; // month
        remoteRtc[6] = 0x12; // year 
        call ClockTimer.startPeriodic(ROUTER_CLOCK_INTERVAL);
        post clockTask();
        break;

      case 'b':
        blinkNodeID = AM_BROADCAST_ADDR;
        post sendBlinkTask();
        break;

      case 'a':
        post setOffloadCookieTask();
        break;

      case 'r':
        break;

      case 'z':
        call LogRead.seek(SEEK_BEGINNING);
        break;

      case 'x':
        call LogRead.seek(flashCookie);
        break;

      case 'c':
        call LogRead.read(flashBuffer, 128);
        break;

      case 'q':
        WDTCTL = 0;
        break;

      case '\r':
        printf("\n\r");
        break;

      default:
        printf("%c", uartByte);
        break;
    }
  }
  
  async event void UartStream.receiveDone( uint8_t* buf_, uint16_t len,
    error_t error ){}
  async event void UartStream.sendDone( uint8_t* buf_, uint16_t len,
    error_t error ){}


}

