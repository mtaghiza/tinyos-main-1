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

#include "bacon_radio_test.h"

module ReceiverP {
  uses interface Boot;
  uses interface Leds;

  uses interface SplitControl;
  uses interface Receive;
  uses interface Packet as RadioPacket;
  uses interface Rf1aPacket;

#ifdef HAS_CC1190
  uses interface CC1190;
  uses interface StdControl as CC1190Control;
#endif

  uses interface SplitControl as SerialSplitControl;
  uses interface AMSend as ReportSend;
  uses interface Packet as SerialPacket;


} implementation {
  message_t _msg;
  message_t* msgPtr;
  bool reporting = FALSE;

  event void Boot.booted(){
    msgPtr = &_msg;
    call SplitControl.start();
  }

  event void SplitControl.startDone(error_t err){
    call SerialSplitControl.start();
  }

  void initCC1190(){
    #ifdef HAS_CC1190
    call CC1190Control.start();
    call CC1190.RXMode(HGM_ENABLED);
    #endif
  }

  event void SerialSplitControl.startDone(error_t err){
    initCC1190();
    //OK, ready to receive
  }


  task void reportRX();

  event message_t *Receive.receive(message_t* msg, void* payload, uint8_t len){
    message_t* swp = msgPtr;
    if (reporting){
      call Leds.set(0x7);
      return msg;
    }
    call Leds.led0Toggle();
    msgPtr = msg;
    reporting = TRUE;
    post reportRX();
    return swp;
  }
  
  message_t smsg;
  task void reportRX(){
    report_t* rpt = (report_t*) (call SerialPacket.getPayload(&smsg, sizeof(report_t)));
    test_payload_t* pl = (test_payload_t*)(call RadioPacket.getPayload(msgPtr, sizeof(test_payload_t)));
    rpt->node_id = pl->node_id;
    rpt->sn = pl->sn;
    rpt->powerLevel = pl->powerLevel;
    rpt->hgmTx = pl->hgm;
    rpt->hgmRx = HGM_ENABLED;
    rpt->rssi = call Rf1aPacket.rssi(msgPtr);
    rpt->lqi = call Rf1aPacket.lqi(msgPtr);
    
    call ReportSend.send(AM_BROADCAST_ADDR, &smsg, sizeof(report_t));
  }

  event void ReportSend.sendDone(message_t* msg, error_t err){
    reporting = FALSE;
  }

  event void SplitControl.stopDone(error_t err){}
  event void SerialSplitControl.stopDone(error_t err){}
}
