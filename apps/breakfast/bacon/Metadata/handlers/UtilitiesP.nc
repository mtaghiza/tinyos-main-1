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

module UtilitiesP{
  uses interface Receive as PingCmdReceive;
  uses interface AMSend as PingResponseSend;
  uses interface Packet;
  uses interface AMPacket;
  uses interface Pool<message_t>;
} implementation {
 
  am_addr_t cmdSource;

  message_t* Ping_cmd_msg = NULL;
  message_t* Ping_response_msg = NULL;
  task void respondPing();

  event message_t* PingCmdReceive.receive(message_t* msg_, 
      void* payload,
      uint8_t len){
    if (Ping_cmd_msg != NULL){
      printf("RX: Ping");
      printf(" BUSY!\n");
      printfflush();
      return msg_;
    }else{
      if ((call Pool.size()) >= 2){
        message_t* ret = call Pool.get();
        Ping_response_msg = call Pool.get();
        Ping_cmd_msg = msg_;
        cmdSource = call AMPacket.source(msg_);
        post respondPing();
        return ret;
      }else{
        printf("RX: Ping");
        printf(" Pool Empty!\n");
        printfflush();
        return msg_;
      }
    }
  }

  task void respondPing(){
    ping_response_msg_t* responsePl = (ping_response_msg_t*)(call Packet.getPayload(Ping_response_msg, sizeof(ping_response_msg_t)));
    responsePl->error = SUCCESS;
    call PingResponseSend.send(cmdSource, Ping_response_msg, sizeof(ping_response_msg_t));
  }

  event void PingResponseSend.sendDone(message_t* msg, 
      error_t error){
    printfflush();
    call Pool.put(Ping_response_msg);
    call Pool.put(Ping_cmd_msg);
    Ping_cmd_msg = NULL;
    Ping_response_msg = NULL;
  }

}
