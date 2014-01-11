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

module TestbedLeafP{
  uses interface DownloadNotify;
  uses interface AMSend;
  uses interface Pool<message_t>;
  uses interface Get<am_addr_t>;
  uses interface CXLinkPacket;
  uses interface Packet;
} implementation {
  message_t* testMsg = NULL;
  uint16_t packetsQueued = 0;

  task void sendAgain(){
    if (!testMsg){
      if (packetsQueued){
        testMsg = call Pool.get();
        if (!testMsg){
          cerror(TESTBED, "Leaf Pool Empty\r\n");
        }else{
          error_t error;
          call Packet.clear(testMsg);
          (call CXLinkPacket.getLinkMetadata(testMsg))->dataPending = (packetsQueued > 1);
          error = call AMSend.send(call Get.get(), testMsg,
            TEST_PAYLOAD_LEN);
           if (SUCCESS != error){
             cerror(TESTBED, "Send %x\r\n", error);
            }
        }
      }
    }
  }

  event void AMSend.sendDone(message_t* msg, error_t error){
    if (error == SUCCESS){
      if (packetsQueued){
        packetsQueued --;
        cinfo(TESTBED, "PQ %u\r\n", packetsQueued);
      }
    }
    call Pool.put(msg);
    testMsg = NULL;
    post sendAgain();
  }

  event void DownloadNotify.downloadStarted(){
    cinfo(TESTBED, "SNDS\r\n");
    packetsQueued += PACKETS_PER_DOWNLOAD;
    cinfo(TESTBED, "PQ %u\r\n", packetsQueued);
    post sendAgain();
  }

  event void DownloadNotify.downloadFinished(){
    cinfo(TESTBED, "SNDF\r\n");
  }
}
