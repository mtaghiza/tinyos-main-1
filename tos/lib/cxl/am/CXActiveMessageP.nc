/* Copyright (c) 2010 People Power Co.
 * All rights reserved.
 *
 * This open source code was developed with funding from People Power Company
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the People Power Corporation nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE
 * PEOPLE POWER CO. OR ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE
 *
 */

/** Implementation of ActiveMessage interfaces on RF1A + CX.
 *
 * @author Peter A. Bigot <pab@peoplepowerco.com>
 * @author Doug Carlson <carlson@cs.jhu.edu>
 */
 #include "CXAM.h"
 #include "CXDebug.h"
module CXActiveMessageP {
  provides interface AMSend[uint8_t ns];
  provides interface Receive[am_id_t id];
  provides interface Receive as Snoop[am_id_t id];
  provides interface PacketAcknowledgements as Acks;

  uses interface Packet;
  uses interface AMPacket;

  uses interface Send as SubSend;
  uses interface Receive as SubReceive;
  uses interface Boot;
}
implementation {

  event void Boot.booted(){
    cinfo(STATS, "START %s\r\n", TEST_DESC);
    cflushinfo(STATS);
  }

  async command error_t Acks.requestAck( message_t* msg ){
    return FAIL;
  }

  async command error_t Acks.noAck( message_t* msg ){
    return SUCCESS;
  }

  async command bool Acks.wasAcked(message_t* msg){
    return FALSE;
  }
  
  uint8_t activeNS;

  command error_t AMSend.send[uint8_t ns](am_addr_t addr,
                                          message_t* msg,
                                          uint8_t len)
  {
    error_t error;
    // Account for layer header in payload length
    uint8_t layerLen = len + sizeof(cx_am_header_t);
    call AMPacket.setSource(msg, call AMPacket.address());
    
    call Packet.setPayloadLength(msg, len);
    error = call SubSend.send(msg, layerLen);
    if (error == SUCCESS){
      activeNS = ns;
    }
    return error;
  }

  command uint8_t AMSend.maxPayloadLength[uint8_t ns]()
  {
    return call Packet.maxPayloadLength();
  }

  command void* AMSend.getPayload[uint8_t ns](message_t* m, uint8_t len)
  {
    return call Packet.getPayload(m, len);
  }

  command error_t AMSend.cancel[uint8_t ns](message_t* msg)
  {
    return call SubSend.cancel(msg);
  }
  
  event void SubSend.sendDone(message_t* msg, error_t error){
    signal AMSend.sendDone[activeNS](msg, error);
  }
  
  message_t* receive(message_t* msg, void* payload_, uint8_t len){
    uint8_t* payload = (uint8_t*)payload_ + sizeof(cx_am_header_t);
    len -= sizeof(cx_am_header_t);

    if (call AMPacket.isForMe(msg)) {
      return signal Receive.receive[call AMPacket.type(msg)](msg, payload, len);
    }else{
      return signal Snoop.receive[call AMPacket.type(msg)](msg, payload, len);
    }
  }


  event message_t* SubReceive.receive(message_t* msg, void* payload_, uint8_t len)
  {
    return receive(msg, payload_, len);
  }

  default event message_t* Receive.receive[am_id_t id](message_t* msg, void* payload, uint8_t len) { return msg; }
  default event message_t* Snoop.receive[am_id_t id](message_t* msg, void* payload, uint8_t len) { return msg; }
  default event void AMSend.sendDone[uint8_t ns](message_t* msg, error_t error) { }
}

/* 
 * Local Variables:
 * mode: c
 * End:
 */
