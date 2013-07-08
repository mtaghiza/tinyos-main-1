// $Id: BaseStationP.nc,v 1.12 2010-06-29 22:07:14 scipio Exp $

/*									tab:4
 * Copyright (c) 2000-2005 The Regents of the University  of California.  
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
 * - Neither the name of the University of California nor the names of
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
 *
 * Copyright (c) 2002-2005 Intel Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE     
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA, 
 * 94704.  Attention:  Intel License Inquiry.
 */

/*
 * @author Phil Buonadonna
 * @author Gilman Tolle
 * @author David Gay
 * Revision:	$Id: BaseStationP.nc,v 1.12 2010-06-29 22:07:14 scipio Exp $
 */
  
/* 
 * BaseStationP bridges packets between a serial channel and the radio.
 * Messages moving from serial to radio will be tagged with the group
 * ID compiled into the BaseStation, and messages moving from radio to
 * serial will be filtered by that same group id.
 */

#include "AM.h"
#include "Serial.h"
#include "CXMac.h"

module BaseStationLppP @safe() {
  uses {
    interface Boot;
    interface SplitControl as SerialControl;
    interface SplitControl as RadioControl;

    interface AMSend as UartSend[am_id_t id];
    interface Receive as UartReceive[am_id_t id];
    interface Packet as UartPacket;
    interface AMPacket as UartAMPacket;
    
    interface AMSend as RadioSend[am_id_t id];
    interface Receive as RadioReceive[am_id_t id];
    interface Receive as RadioSnoop[am_id_t id];
    interface Packet as RadioPacket;
    interface AMPacket as RadioAMPacket;

    interface Leds;
  }

  uses interface Leds as CXLeds;
  uses interface LppControl;
  uses interface CXMacMaster;

  uses interface CXLinkPacket;

  uses interface Timer<TMilli> as WakeupTimeout;
  uses interface Timer<TMilli> as SleepDelay;
}

implementation
{
  uint8_t aux[TOSH_DATA_LENGTH];

  bool ctsPending;
  am_addr_t ctsAddr;

  enum {
    UART_QUEUE_LEN = 4,
    RADIO_QUEUE_LEN = 4,
  };

  message_t  uartQueueBufs[UART_QUEUE_LEN];
  message_t  * ONE_NOK uartQueue[UART_QUEUE_LEN];
  uint8_t    uartIn, uartOut;
  bool       uartBusy, uartFull;

  message_t  radioQueueBufs[RADIO_QUEUE_LEN];
  message_t  * ONE_NOK radioQueue[RADIO_QUEUE_LEN];
  uint8_t    radioIn, radioOut;
  bool       radioBusy, radioFull;

  task void uartSendTask();
  task void radioSendTask();

  void dropBlink() {
    call Leds.led2Toggle();
  }

  void failBlink() {
    call Leds.led2Toggle();
  }

  event void Boot.booted() {
    uint8_t i;

    for (i = 0; i < UART_QUEUE_LEN; i++)
      uartQueue[i] = &uartQueueBufs[i];
    uartIn = uartOut = 0;
    uartBusy = FALSE;
    uartFull = TRUE;

    for (i = 0; i < RADIO_QUEUE_LEN; i++)
      radioQueue[i] = &radioQueueBufs[i];
    radioIn = radioOut = 0;
    radioBusy = FALSE;
    radioFull = TRUE;

    if (call RadioControl.start() == EALREADY)
      radioFull = FALSE;
    if (call SerialControl.start() == EALREADY)
      uartFull = FALSE;
    
    #ifdef CC430_PIN_DEBUG
    atomic{
      //map SFD to 1.2
      PMAPPWD = PMAPKEY;
      PMAPCTL = PMAPRECFG;
      P2MAP4 = PM_RFGDO0;
      PMAPPWD = 0x00;
  
      //set as output/function
      P2SEL |= BIT4;
      P2DIR |= BIT4;
  
      //disable flash chip
      P2SEL &= ~BIT1;
      P2OUT |=  BIT1;
    }
    #endif
  }

  event void RadioControl.startDone(error_t error) {
    if (error == SUCCESS) {
      radioFull = FALSE;
    }
  }

  event void SerialControl.startDone(error_t error) {
    if (error == SUCCESS) {
      uartFull = FALSE;
    }
  }

  event void SerialControl.stopDone(error_t error) {}
  event void RadioControl.stopDone(error_t error) {}

  uint8_t count = 0;

  message_t* ONE receive(message_t* ONE msg, void* payload, uint8_t len);
  
  event message_t *RadioSnoop.receive[am_id_t id](message_t *msg,
						    void *payload,
						    uint8_t len) {
//    printf("SNOOP %x\r\n", id);
//    printfflush();
    return receive(msg, payload, len);
  }
  
  event message_t *RadioReceive.receive[am_id_t id](message_t *msg,
						    void *payload,
						    uint8_t len) {
//    printf("RRR %x from %u\r\n", id, 
//      call RadioAMPacket.source(msg));
//    printfflush();
//    printf("RECEIVE %x from %u pl len %u msg len %u:\n", id, 
//      call RadioAMPacket.source(msg), 
//      len, 
//      sizeof(msg));
//    printfflush();
    return receive(msg, payload, len);
  }

  message_t* receive(message_t *msg, void *payload, uint8_t len) {
    message_t *ret = msg;
    atomic {
      if (!uartFull)
	{
	  ret = uartQueue[uartIn];
	  uartQueue[uartIn] = msg;

	  uartIn = (uartIn + 1) % UART_QUEUE_LEN;
	
	  if (uartIn == uartOut)
	    uartFull = TRUE;

	  if (!uartBusy)
	    {
	      post uartSendTask();
	      uartBusy = TRUE;
	    }
	}
      else
	dropBlink();
    }
    
    return ret;
  }


  task void uartSendTask() {
    uint8_t len;
    am_id_t id;
    am_addr_t addr, src;
    message_t* msg;
    am_group_t grp;
    atomic
      if (uartIn == uartOut && !uartFull)
	{
	  uartBusy = FALSE;
	  return;
	}

    msg = uartQueue[uartOut];
    len = call RadioPacket.payloadLength(msg);
    id = call RadioAMPacket.type(msg);
    addr = call RadioAMPacket.destination(msg);
    src = call RadioAMPacket.source(msg);
    grp = call RadioAMPacket.group(msg);
    
    //clears the serial header only: leaves body intact.
    call UartPacket.clear(msg);
    
    if (call UartSend.send[id](addr, uartQueue[uartOut], len) == SUCCESS){
      call UartAMPacket.setSource(msg, src);
      call UartAMPacket.setGroup(msg, grp);
      memmove( call UartPacket.getPayload(msg, len),
        call RadioPacket.getPayload(msg, len), 
        len);
      call Leds.led1Toggle();
    }else {
      call RadioAMPacket.setSource(msg, src);
      call RadioAMPacket.setGroup(msg, grp);
      failBlink();
      post uartSendTask();
    }
  }
  

  event void UartSend.sendDone[am_id_t id](message_t* msg, error_t error) {
    if (id != AM_PRINTF_MSG){
      printfflush();
      if (error != SUCCESS){
        failBlink();
      } else{
        atomic{
          if (msg == uartQueue[uartOut]) {
            if (++uartOut >= UART_QUEUE_LEN){
              uartOut = 0;
            }
            if (uartFull){
              uartFull = FALSE;
            }
          }
        }
      }
    }
    post uartSendTask();
  }

  event void LppControl.wokenUp(){
    call CXLeds.led0On();
//    printf("BS WAKEUP\r\n");
//    printfflush();
  }
  event void LppControl.fellAsleep(){
    printf("BS SLEEP\r\n");
    printfflush();
    call CXLeds.led0Off();
  }

  event void CXMacMaster.ctsDone(am_addr_t src, error_t error){
    ctsPending = FALSE;
    if (error == SUCCESS){
      call CXLeds.led1Off();
    }else{
      call CXLeds.led2On();
    }
  }


  event void WakeupTimeout.fired(){
//    printf("Wakeup Timeout\r\n");
    if (call LppControl.isAwake()){
      if (call LppControl.sleep() != SUCCESS){
        atomic{
          printf("Sleep failed, hard reset\r\n");
          printfflush();
          WDTCTL = 0;
        }
      }
    }
  }

  event void SleepDelay.fired(){
//    printf("Sleeping\r\n");
    if (call LppControl.isAwake()){
      if (call LppControl.sleep() != SUCCESS){
        atomic{
          printf("Sleep failed, hard reset\r\n");
          printfflush();
          WDTCTL = 0;
        }
      }
    }
  }

  task void ctsTask(){
    error_t error = call CXMacMaster.cts(ctsAddr);
    if ( error != SUCCESS){
      ctsPending = FALSE;
      printf("CTS failed: %x\r\n", error);
      printfflush();
      call CXLeds.led2On();
    }else{
      ctsPending = TRUE;
      call CXLeds.led1On();
    }
  }

  event message_t *UartReceive.receive[am_id_t id](message_t *msg,
						   void *payload,
						   uint8_t len) {
    if (id == AM_CX_LPP_WAKEUP){
      cx_lpp_wakeup_t* pl = payload;
      if (! call LppControl.isAwake()){
        if (call LppControl.wakeup() != SUCCESS){
          call CXLeds.led2On();
        }
      }
      call WakeupTimeout.startOneShot(pl->timeout);
      return msg;
    } else if (id == AM_CX_LPP_SLEEP){
      cx_lpp_sleep_t* pl = payload;
      if (call LppControl.isAwake()){
        call WakeupTimeout.stop();
        call SleepDelay.startOneShot(pl->delay);
      }else{
        printf("Already sleeping\r\n");
      }
      return msg;
    } else if (id == AM_CX_LPP_CTS){
      if (!ctsPending){
        ctsAddr = ((cx_lpp_cts_t*)payload)->addr;
        ctsPending = TRUE;
        post ctsTask();
      }else{
        printf("CTS still pending\r\n");
        printfflush();
      }
      return msg;
    } else {
      message_t *ret = msg;
      bool reflectToken = FALSE;
      call CXLeds.led2Toggle();
  
      atomic
        if (!radioFull)
  	{
  	  reflectToken = TRUE;
  	  ret = radioQueue[radioIn];
  	  radioQueue[radioIn] = msg;
  	  if (++radioIn >= RADIO_QUEUE_LEN)
  	    radioIn = 0;
  	  if (radioIn == radioOut)
  	    radioFull = TRUE;
  
  	  if (!radioBusy)
  	    {
  	      post radioSendTask();
  	      radioBusy = TRUE;
  	    }
  	}
        else
  	dropBlink();
  
      if (reflectToken) {
        //call UartTokenReceive.ReflectToken(Token);
      }
      
      return ret;
    }
    printfflush();
  }

  task void radioSendTask() {
    uint8_t len;
    am_id_t id;
    am_addr_t addr,source;
    message_t* msg;
    
    atomic
      if (radioIn == radioOut && !radioFull)
	{
	  radioBusy = FALSE;
	  return;
	}

    msg = radioQueue[radioOut];
    len = call UartPacket.payloadLength(msg);
    addr = call UartAMPacket.destination(msg);
    source = call UartAMPacket.source(msg);
    id = call UartAMPacket.type(msg);
    
    //move payload out of the way before clearing packet: header
    //length mismatch might kill it.
    memmove( aux,
      call UartPacket.getPayload(msg, len), 
      len);
    call RadioPacket.clear(msg);
    call RadioAMPacket.setSource(msg, source);
    
    //move payload into correct position
    memmove( call RadioPacket.getPayload(msg, len), 
      aux, len);
    if (call RadioSend.send[id](addr, msg, len) == SUCCESS){
      call Leds.led0Toggle();
    }else {
      //restore payload to original (uart) position.
      memmove( call UartPacket.getPayload(msg, len), 
        aux, len);
      call UartAMPacket.setDestination(msg, addr);
      call UartAMPacket.setSource(msg, source);
      failBlink();
      post radioSendTask();
    }
  }

  event void RadioSend.sendDone[am_id_t id](message_t* msg, error_t error) {
    if (error != SUCCESS)
      failBlink();
    else
      atomic
	if (msg == radioQueue[radioOut])
	  {
	    if (++radioOut >= RADIO_QUEUE_LEN)
	      radioOut = 0;
	    if (radioFull)
	      radioFull = FALSE;
	  }
    
    post radioSendTask();
  }
}  
