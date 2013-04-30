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
 #include "CXAMDebug.h"
module CXActiveMessageP {
  provides {
    interface AMSend[am_id_t id];
    interface Receive[am_id_t id];
    interface Receive as Snoop[am_id_t id];
    interface PacketAcknowledgements as Acks;
  }
  uses {
    interface Rf1aPacket;
    interface Ieee154Packet;
    interface Packet;
    interface AMPacket;
    interface CXPacketMetadata;
  }
  uses interface Send as ScheduledSend;
  uses interface Send as BroadcastSend;
  uses interface Send as UnicastSend;
  uses interface Receive as BroadcastReceive;
  uses interface Receive as UnicastReceive;
}
implementation {
  /** Convenience typedef denoting the structure used as a header in
   * this packet layout. */
  typedef rf1a_nalp_am_t layer_header_t;

  async command error_t Acks.requestAck( message_t* msg ){
    return FAIL;
  }

  async command error_t Acks.noAck( message_t* msg ){
    return SUCCESS;
  }

  async command bool Acks.wasAcked(message_t* msg){
    return FALSE;
  }
  

  command error_t AMSend.send[am_id_t id](am_addr_t addr,
                                          message_t* msg,
                                          uint8_t len)
  {
    error_t rc;
    // Account for layer header in payload length
    uint8_t layerLen = len + sizeof(layer_header_t);
    call Rf1aPacket.configureAsData(msg);
    call AMPacket.setSource(msg, call AMPacket.address());
    call Ieee154Packet.setPan(msg, call Ieee154Packet.localPan());
    call AMPacket.setDestination(msg, addr);
    call AMPacket.setType(msg, id);
    
    if (call CXPacketMetadata.getRequestedFrame(msg) != INVALID_FRAME){
      rc = call ScheduledSend.send(msg, layerLen);
    }else if (addr == AM_BROADCAST_ADDR){
      rc = call BroadcastSend.send(msg, layerLen);
    } else {
      rc = call UnicastSend.send(msg, layerLen);
    }
    return rc;
  }

  command uint8_t AMSend.maxPayloadLength[am_id_t id]()
  {
    return call Packet.maxPayloadLength();
  }

  command void* AMSend.getPayload[am_id_t id](message_t* m, uint8_t len)
  {
    return call Packet.getPayload(m, len);
  }

  command error_t AMSend.cancel[am_id_t id](message_t* msg)
  {
    return FAIL;
  }
  
  void sendDone(message_t* msg, error_t error, uint8_t from){
    cdbg(AM, "sd %p from %x\r\n", msg, from);
    signal AMSend.sendDone[call AMPacket.type(msg)](msg, error);
  }

  event void BroadcastSend.sendDone(message_t* msg, error_t error)
  {
    sendDone(msg, error, 0);
  }

  event void ScheduledSend.sendDone(message_t* msg, error_t error)
  {
    sendDone(msg, error, 2);
  }

  event void UnicastSend.sendDone(message_t* msg, error_t error)
  {
    sendDone(msg, error, 1);
  }
  
  message_t* receive(message_t* msg, void* payload_, uint8_t len){
    uint8_t* payload = (uint8_t*)payload_ + sizeof(layer_header_t);
    len -= sizeof(layer_header_t);
    #ifdef RF1A_NO_CRC
    #warning Skipping SW CRC Check!
    #else
    if (! call Rf1aPacket.crcPassed(msg)){
      return msg;
    }
    #endif
    if (call AMPacket.isForMe(msg)) {
      return signal Receive.receive[call AMPacket.type(msg)](msg, payload, len);
    }

    return signal Snoop.receive[call AMPacket.type(msg)](msg, payload, len);
  }

  event message_t* BroadcastReceive.receive(message_t* msg, void* payload_, uint8_t len)
  {
    return receive(msg, payload_, len);
  }

  event message_t* UnicastReceive.receive(message_t* msg, void* payload_, uint8_t len)
  {
    return receive(msg, payload_, len);
  }

  default event message_t* Receive.receive[am_id_t id](message_t* msg, void* payload, uint8_t len) { return msg; }
  default event message_t* Snoop.receive[am_id_t id](message_t* msg, void* payload, uint8_t len) { return msg; }
  default event void AMSend.sendDone[am_id_t amId](message_t* msg, error_t error) { }
}

/* 
 * Local Variables:
 * mode: c
 * End:
 */
