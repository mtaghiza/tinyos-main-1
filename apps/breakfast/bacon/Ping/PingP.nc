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

module PingP {
  uses interface Get<uint16_t> as RebootCounter;
  uses interface LocalTime<TMilli> as LocalTimeMilli;
  uses interface LocalTime<T32khz> as LocalTime32k;

  uses interface Receive;
  uses interface AMSend;
  uses interface Pool<message_t>;

  uses interface AMPacket;
  uses interface Packet;
} implementation {
  
  message_t* pkt = NULL;
  uint32_t tm;
  uint32_t t32k;

  task void handlePing(){
    ping_msg_t* pingPl = call Packet.getPayload(pkt,
      sizeof(ping_msg_t));
    uint32_t pingId = pingPl->pingId;
    am_addr_t from = call AMPacket.source(pkt);
    pong_msg_t* pongPl = call Packet.getPayload(pkt,
      sizeof(pong_msg_t));
    error_t error;
    call Packet.clear(pkt);
    pongPl->pingId = pingId;
    pongPl->rebootCounter = call RebootCounter.get();
    pongPl->tsMilli = tm;
    pongPl->ts32k   = t32k;
    error = call AMSend.send(from, pkt, sizeof(pong_msg_t));
    if (SUCCESS != error){
      call Pool.put(pkt);
    }
  }

  event message_t* Receive.receive(message_t* msg, void* pl, uint8_t len){
    if (pkt != NULL){
      return msg;
    }else{
      message_t* ret;
      t32k = call LocalTime32k.get();
      tm = call LocalTimeMilli.get();
      ret = call Pool.get();
      if (ret == NULL){
        return msg;
      }
      pkt = msg;
      post handlePing();
      return ret;
    }
  }

  event void AMSend.sendDone(message_t* msg, error_t error){
    if (msg == pkt){
      call Pool.put(pkt);
      pkt = NULL;
    }
  }
}
