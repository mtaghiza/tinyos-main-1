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

module NfcP{
  uses interface Boot;
  uses interface Leds;
  uses interface Random;

  /* Timers */  
  uses interface Timer<TMilli> as StatusTimer;
  uses interface Timer<TMilli> as WDTResetTimer;
  uses interface Timer<TMilli> as LedsTimer;

  /* UART */
  uses interface StdControl as SerialControl;
  uses interface UartStream;

  /* Radio */
  uses interface SplitControl as RadioControl;
  uses interface AMSend as ControlSend;


  uses interface Packet;
  uses interface AMPacket;
  uses interface Rf1aPacket;

} implementation {

  void printMessage(void*);

  uint8_t __attribute__ ((section(".noinit"))) boot_counter;

  
  message_t controlMessage;

  /*************************/
  uint8_t ledsGet;
  uint16_t blinkNodeID;
  task void blinkTask();
  task void sendBlinkTask();
  
  /*************************/
  event void Boot.booted()
  {
    uint16_t reset_vector = SYSRSTIV;
    if (reset_vector == 0x04)
      boot_counter = 0;
    else
      ++boot_counter;
      
      
      
    call SerialControl.start();
    call WDTResetTimer.startPeriodic(512);
    
    //set WDT to reset at 1 second
    WDTCTL = WDT_ARST_1000;



    printf("root: %d %X\n\r", boot_counter, reset_vector);

    call RadioControl.start();
    call StatusTimer.startPeriodic(1024 * 5);
  }


  /***************************************************************************/
  /* Timers                                                                  */
  /***************************************************************************/
    
  event void StatusTimer.fired()
  {
    post blinkTask();

    blinkNodeID = AM_BROADCAST_ADDR;
    post sendBlinkTask();
  }

  event void WDTResetTimer.fired() {
    //re-up the wdt
    WDTCTL =  WDT_ARST_1000;
  }


  task void blinkTask()
  {
    ledsGet = LEDS_LED0|LEDS_LED1|LEDS_LED2;
    call Leds.set(LEDS_LED0|LEDS_LED1|LEDS_LED2);

    call LedsTimer.startOneShot(512);
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
    post blinkTask();

    printf("radio on\n\r");    
  }


  /***************************************************************************/

  /* Control - Blink LEDS on node NODEID */  
  task void sendBlinkTask()
  {   
    control_t * controlPointer = (control_t*) call Packet.getPayload(&controlMessage, sizeof(control_t));

    controlPointer->length = sizeof(control_t);
    controlPointer->type = TYPE_CONTROL_BLINK_LINK;
    controlPointer->destination = blinkNodeID;

    call ControlSend.send(blinkNodeID, &controlMessage, sizeof(control_t));
  }
    

  event void ControlSend.sendDone(message_t* msg_, error_t err) 
  {
    if (err != SUCCESS)
      printf("send failed\n\r");
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
        break;

      case 'b':
        blinkNodeID = AM_BROADCAST_ADDR;
        post sendBlinkTask();
        break;

      case 'a':
        break;

      case 'r':
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

