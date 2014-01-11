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

module AMStatsLogP {
  provides interface StatsLog;
  uses interface CXLinkPacket;
  uses interface Packet;

  uses interface AMSend as RadioSend;
  uses interface AMSend as RXSend;
  uses interface AMSend as TXSend;
  uses interface Pool<message_t>;

  uses interface Packet as SerialPacket;
} implementation {
  
  command void StatsLog.logSlotStats(cx_link_stats_t stats, 
      uint16_t wakeupNum, uint16_t slotNum, 
      uint8_t slotRole){
    message_t* msg = call Pool.get();
    if (msg != NULL){
      stats_log_radio_t* pl = call RadioSend.getPayload(msg,
        sizeof(stats_log_radio_t));
      call SerialPacket.clear(msg);
      //TODO: fill in pl
      if (SUCCESS != call RadioSend.send(0, msg,
          sizeof(stats_log_radio_t))){
        call Pool.put(msg);
      }
    }
  }

  event void RadioSend.sendDone(message_t* msg, error_t error){
    call Pool.put(msg);
  }

  command void StatsLog.logReception(message_t* msg,
      uint16_t wakeupNum, uint16_t slotNum){
    message_t* logMsg = call Pool.get();
    if (logMsg != NULL){
      stats_log_rx_t* pl = call RXSend.getPayload(logMsg, 
        sizeof(stats_log_rx_t));
      call SerialPacket.clear(logMsg);
      if (SUCCESS != call RXSend.send(0, logMsg, sizeof(stats_log_rx_t))){
        call Pool.put(logMsg);
      }
    }
  }

  event void RXSend.sendDone(message_t* msg, error_t error){
    call Pool.put(msg);
  }

  command void StatsLog.logTransmission(message_t* msg, 
      uint16_t wakeupNum, uint16_t slotNum){
    message_t* logMsg = call Pool.get();
    if (logMsg != NULL){
      stats_log_tx_t* pl = call TXSend.getPayload(logMsg, 
        sizeof(stats_log_tx_t));
      call SerialPacket.clear(logMsg);
      if (SUCCESS != call TXSend.send(0, logMsg, sizeof(stats_log_tx_t))){
        call Pool.put(logMsg);
      }
    }
  }

  event void TXSend.sendDone(message_t* msg, error_t error){
    call Pool.put(msg);
  }

  command void StatsLog.flush(){}
}
