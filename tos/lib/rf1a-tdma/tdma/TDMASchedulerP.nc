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


 #include "schedule.h"
 #include "stateSafety.h"
module TDMASchedulerP{
  provides interface SplitControl;
  provides interface CXTDMA;
  provides interface TDMAScheduler;
  provides interface TDMARootControl;

  uses interface SplitControl as SubSplitControl;
  uses interface CXTDMA as SubCXTDMA;

  uses interface AMPacket; 
  uses interface CXPacket; 
  uses interface Packet; 
  uses interface Rf1aPacket; 
  uses interface Ieee154Packet;
} implementation {
  enum{
    ERROR_MASK = 0x80,
    S_ERROR_1 = 0x81,
    S_ERROR_2 = 0x82,
    S_ERROR_3 = 0x83,
    S_ERROR_4 = 0x84,
    S_ERROR_5 = 0x85,
    S_ERROR_6 = 0x86,
    S_ERROR_7 = 0x87,
    S_ERROR_8 = 0x88,
    S_ERROR_9 = 0x89,
    S_ERROR_a = 0x8a,
    S_ERROR_b = 0x8b,
    S_ERROR_c = 0x8c,
    S_ERROR_d = 0x8d,
    S_ERROR_e = 0x8e,
    S_ERROR_f = 0x8f,

    S_OFF = 0x00,
    S_STARTING = 0x01,
    S_STOPPING = 0x02,

    S_R_UNSCHEDULED = 0x10,
    S_R_RUNNING = 0x11,

    S_NR_UNSCHEDULED = 0x20,
    S_NR_RUNNING     = 0x21,
  };

  uint8_t state = S_OFF;
  //macro for state-safety
  SET_STATE_DEF

  bool updatePending = FALSE;
  //protected by updatePending
  norace uint32_t lastFs;
  norace cx_schedule_t lastSchedule;

  uint16_t _activeFrames;
  uint16_t _inactiveFrames;
  uint16_t _framesPerSlot;
  uint16_t _maxRetransmit; 

  void setupPacket(message_t* schedule_msg, uint32_t frameLen,
  uint32_t fwCheckLen, uint16_t activeFrames, uint16_t inactiveFrames,
  uint16_t framesPerSlot, uint8_t maxRetransmit, uint16_t originalFrame){
    cx_schedule_t* schedule_pl;
    call CXPacket.init(schedule_msg);

    call AMPacket.setDestination(schedule_msg, AM_BROADCAST_ADDR);
    call CXPacket.setDestination(schedule_msg, AM_BROADCAST_ADDR);
    call CXPacket.setType(schedule_msg, CX_TYPE_SCHEDULE);
    schedule_pl = (cx_schedule_t*)call Packet.getPayload(schedule_msg, sizeof(cx_schedule_t));
    schedule_pl -> rootStart = 0;
    schedule_pl -> originalFrame = originalFrame;
    schedule_pl -> frameLen = frameLen;
    schedule_pl -> activeFrames = activeFrames;
    schedule_pl -> inactiveFrames = inactiveFrames;
    schedule_pl -> framesPerSlot = framesPerSlot;
    schedule_pl -> maxRetransmit = maxRetransmit;
  }


  command error_t SplitControl.start(){
    error_t error;
    TMP_STATE;
    CACHE_STATE;
    error = call SubSplitControl.start();
    if (SUCCESS == error){
      SET_STATE(S_STARTING, S_ERROR_1);
    } else {
      SET_ESTATE(S_ERROR_1);
    }
    return error;
  }

  command error_t SplitControl.stop(){
    return call SubSplitControl.stop();
  }

  task void nrSetup(){
    error_t error;
    TMP_STATE;
    CACHE_STATE;
    error = call SubCXTDMA.setSchedule(
      call SubCXTDMA.getNow(), 
      0,
      10*DEFAULT_TDMA_FRAME_LEN,
      2*10*DEFAULT_TDMA_FRAME_LEN,
      1, 0);
    if (SUCCESS == error){
      SET_STATE(S_NR_UNSCHEDULED, S_ERROR_2);
    }
  }

  event void SubSplitControl.startDone(error_t error){
    TMP_STATE;
    CACHE_STATE;
    if (SUCCESS == error){
      if (signal TDMARootControl.isRoot()){
        if ( SET_STATE(S_R_UNSCHEDULED, S_ERROR_3)){
          signal SplitControl.startDone(SUCCESS);
        } else {
          signal SplitControl.startDone(FAIL);
        }
      } else {
        post nrSetup();
      }
    }else{
      SET_ESTATE(S_ERROR_3);
      signal SplitControl.startDone(error);
    }
  }

  event void SubSplitControl.stopDone(error_t error){
    TMP_STATE;
    CACHE_STATE;
    if (SUCCESS == error){
      SET_STATE(S_OFF, S_ERROR_4);
    } else {
      SET_ESTATE(S_ERROR_4);
    }
    signal SplitControl.stopDone(error);
  }

  //calls should go through the TDMAScheduler interface.
  command error_t CXTDMA.setSchedule(uint32_t startAt,
      uint16_t atFrameNum, uint32_t frameLen, 
      uint32_t fwCheckLen, uint16_t activeFrames, 
      uint16_t inactiveFrames){
    return FAIL;
  }

  task void signalScheduled(){
    signal TDMAScheduler.scheduleReceived(_activeFrames,
      _inactiveFrames, _framesPerSlot,
      _maxRetransmit);
  }
  
  command error_t TDMARootControl.setSchedule(uint32_t frameLen, 
      uint32_t fwCheckLen, uint16_t activeFrames, 
      uint16_t inactiveFrames, uint16_t framesPerSlot, 
      uint16_t maxRetransmit, uint16_t originalFrame, 
      message_t* announcement){
    TMP_STATE;
    CACHE_STATE;
    if (CHECK_STATE(S_R_UNSCHEDULED) || CHECK_STATE(S_R_RUNNING)){
      error_t error = call SubCXTDMA.setSchedule(
        call SubCXTDMA.getNow(), originalFrame, frameLen, fwCheckLen, activeFrames, inactiveFrames);
      if (SUCCESS == error){
        _activeFrames = activeFrames;
        _inactiveFrames = inactiveFrames;
        _framesPerSlot = framesPerSlot;
        _maxRetransmit = maxRetransmit;
        setupPacket(announcement, frameLen, fwCheckLen, activeFrames,
          inactiveFrames, framesPerSlot, maxRetransmit, originalFrame);
        post signalScheduled();
        SET_STATE(S_R_RUNNING, S_ERROR_5);
      } else {
        SET_ESTATE(S_ERROR_5);
      }
      return error;
    } else{
      return FAIL;
    }
  }

  async command uint32_t CXTDMA.getNow(){
    return call SubCXTDMA.getNow();
  }

  /**
   *  Root broadcasts during frame 0. All other behavior is up to
   *  higher levels.
   *
   */
  async event rf1a_offmode_t SubCXTDMA.frameType(uint16_t frameNum){
    if (state == S_NR_UNSCHEDULED){
      return RF1A_OM_RX;
    } else {
      return signal CXTDMA.frameType(frameNum);
    }
  }
  
  //root is responsible for providing the packet itself (via some
  //routing layer)
  async event bool SubCXTDMA.getPacket(message_t** msg, uint8_t* len,
      uint16_t frameNum){
    return signal CXTDMA.getPacket(msg, len, frameNum);
  }


  async event void SubCXTDMA.sendDone(message_t* msg, uint8_t len,
      uint16_t frameNum, error_t error){
    signal CXTDMA.sendDone(msg, len, frameNum, error);
  }
 

  task void processReceive(){
    TMP_STATE;
    error_t error;
    CACHE_STATE;
    error = call SubCXTDMA.setSchedule(lastFs, 
      lastSchedule.originalFrame,
      lastSchedule.frameLen, 
      DEFAULT_TDMA_FW_CHECK_LEN,
      lastSchedule.activeFrames,
      lastSchedule.inactiveFrames);
    atomic updatePending = FALSE;
    if (SUCCESS != error){
      printf("Error %s\r\n", decodeError(error));
      SET_ESTATE(S_ERROR_6);
    } else {
      if (CHECK_STATE(S_NR_UNSCHEDULED)){
//        printf("scheduled\r\n");
        SET_STATE(S_NR_RUNNING, S_ERROR_6);
        signal SplitControl.startDone(SUCCESS);
      } else {
//        printf("updated\r\n");
      }
      signal TDMAScheduler.scheduleReceived(lastSchedule.activeFrames,
        lastSchedule.inactiveFrames, lastSchedule.framesPerSlot,
        lastSchedule.maxRetransmit);
    }
  }

  async event message_t* SubCXTDMA.receive(message_t* msg, 
      uint8_t len, uint16_t frameNum, uint32_t timestamp){
    //if we're in need of a schedule, grab it now before signalling
    //this up to the upper layers (which may lay claim to this
    //buffer).
//    printf("s %x f %u t %x\r\n", state, frameNum, 
//      call CXPacket.type(msg));
    if ((state == S_NR_UNSCHEDULED) || 
         ((state == S_NR_RUNNING) 
           && (frameNum == 0) 
           && (call CXPacket.type(msg) == CX_TYPE_SCHEDULE))){
      cx_schedule_t* pl;
      bool okToProceed = TRUE;

      atomic {
        if (!updatePending){
          updatePending = TRUE;
        //still haven't handled previous update.
        } else{
          okToProceed = FALSE;
        }
      }
      if (okToProceed){
        pl = (cx_schedule_t*)call Packet.getPayload(msg, len);
  //      printf("RX schedule\r\n");
  //      lastSchedule.rootStart = pl->rootStart;
        lastSchedule.originalFrame = 
          call CXPacket.count(msg) + pl->originalFrame - 1;
        lastSchedule.frameLen = pl->frameLen;
        lastSchedule.activeFrames = pl->activeFrames;
        lastSchedule.inactiveFrames = pl->inactiveFrames;
        lastSchedule.framesPerSlot = pl->framesPerSlot;
        lastSchedule.maxRetransmit = pl->maxRetransmit;
        //TODO: store the time that this frame started as well. Need
        //that for drift correction.
        post processReceive();
      }
    }else{
      //this layer doesn't care what it is.
//      return msg;
    }
    return signal CXTDMA.receive(msg, len, frameNum, timestamp);
  }

  async event void SubCXTDMA.frameStarted(uint32_t startTime, 
      uint16_t frameNum){
    //TODO: if we're not root and too much time has elapsed since last
    //  synch, post nrSetup()
    //TODO: if this frameNum > 2*framesPerSlot, then we should assume
    //  that we've missed the schedule for this round and should
    //  maintain our duty cycling (as we are probably not too far
    //  off). However, we should not allow transmissions to take
    //  place, since we don't know how far off we are from the rest of
    //  the network.

    if (!updatePending){
      lastFs = startTime;
    } else {
      SET_ESTATE(S_ERROR_8);
    }
    signal CXTDMA.frameStarted(startTime, frameNum);
    //TODO: add another event that indicates "we're inactive now"?
  }

}
