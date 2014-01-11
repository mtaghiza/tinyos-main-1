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

module CXSlaveP {
  provides interface SlotController;
  provides interface CTS[uint8_t ns];
  uses interface Get<probe_schedule_t*> as GetProbeSchedule;
  provides interface Get<am_addr_t> as GetRoot[uint8_t ns];
} implementation {
  am_addr_t masters[NUM_SEGMENTS] = {AM_BROADCAST_ADDR, 
                                     AM_BROADCAST_ADDR, 
                                     AM_BROADCAST_ADDR};

  command am_addr_t GetRoot.get[uint8_t ns](){
    return masters[ns];
  }

  command am_addr_t SlotController.activeNode(){
    return AM_BROADCAST_ADDR;
  }
  command bool SlotController.isMaster(){
    return FALSE;
  }
  command bool SlotController.isActive(){
    return FALSE;
  }
  command uint8_t SlotController.bw(uint8_t ns){
    probe_schedule_t* sched = call GetProbeSchedule.get();
    return sched->bw[ns];
  }
  command uint8_t SlotController.maxDepth(uint8_t ns){
    probe_schedule_t* sched = call GetProbeSchedule.get();
    return sched->maxDepth[ns];
  }
  command message_t* SlotController.receiveEOS(
      message_t* msg, cx_eos_t* pl){
    return msg;
  }
  command message_t* SlotController.receiveStatus(
      message_t* msg, cx_status_t *pl){
    return msg;
  }
  command void SlotController.endSlot(){
  }
  command void SlotController.receiveCTS(am_addr_t master, 
      uint8_t ns){
    masters[ns] = master;
    signal CTS.ctsReceived[ns]();
  }

  default event void CTS.ctsReceived[uint8_t ns](){
  }
}
