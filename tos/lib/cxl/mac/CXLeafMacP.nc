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

module CXLeafMacP {
  provides interface CXMacController;
  provides interface Receive;
  uses interface Receive as SubReceive;
  uses interface CXMacPacket;
  uses interface CXLinkPacket;

  provides interface Send;
  uses interface Send as SubSend;
  uses interface ActiveMessageAddress;
} implementation {
  message_t* pendingMsg = NULL;

  task void signalGranted(){
    pendingMsg = NULL;
    signal CXMacController.requestGranted();
  }

  event message_t* SubReceive.receive(message_t* msg, 
      void* pl, uint8_t len){
    if (call CXMacPacket.getMacType(msg) == CXM_CTS 
        && (call CXLinkPacket.getLinkHeader(msg))->destination == call ActiveMessageAddress.amAddress()
        && pendingMsg){
      post signalGranted();
      return msg;
    }else if (call CXMacPacket.getMacType(msg) == CXM_DATA){
      return signal Receive.receive(msg, 
        pl+sizeof(cx_mac_header_t),
        len-sizeof(cx_mac_header_t));
    }else{
      return msg;
    }

  }

  command error_t CXMacController.requestSend(message_t* msg){
    if (pendingMsg){
      return EBUSY;
    }else{
      pendingMsg = msg;
      return SUCCESS;
    }
  }

  command error_t Send.send(message_t* msg, uint8_t len){
    call CXMacPacket.setMacType(msg, CXM_DATA);
    return call SubSend.send(msg, len);
  }

  event void SubSend.sendDone(message_t* msg, error_t error){
    signal Send.sendDone(msg, error);
  }
  
  command void* Send.getPayload(message_t* msg, uint8_t len){
    return call SubSend.getPayload(msg, len);
  }
  command uint8_t Send.maxPayloadLength(){
    return call SubSend.maxPayloadLength();
  }
  command error_t Send.cancel(message_t* msg){
    return call SubSend.cancel(msg);
  }
  
  async event void ActiveMessageAddress.changed(){}
  
}
