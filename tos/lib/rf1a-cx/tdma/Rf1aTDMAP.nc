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

generic module Rf1aTDMAP (){
  provides interface SplitControl;
  provides interface CXTDMA;
  provides interface Receive[uint8_t cxType];

  uses interface Rf1aPhysical;
  uses interface Resource;

  uses interface Alarm<TMicro, uint32_t> as FrameAlarm;
  uses interface Alarm<TMicro, uint32_t> as PrepareFrameAlarm;
  //TODO: Msp430Capture interface/matching control
} implementation {

  enum{
    
    ERROR_MASK = 0x80,
    S_ERROR = 0x81,
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

    S_OFF,
    S_INACTIVE,
    S_IDLE,
    S_RX_STARTING,
    S_CS_CHECK,
    S_FS_CHECK,
    S_RECEIVING,
    S_RX_CLEANUP,
    S_TX_STARTING,
    S_TX_READY,
    S_TX_CLEANUP,
  };

  /**
    S_OFF: off/not duty cycled
      SplitControl.start / resource.request -> S_STARTING
    
    S_STARTING: radio core starting up/calibrating
      resource.granted / -  -> S_IDLE

    S_IDLE: in the part of a frame where no data is expected.
      PFS.fired + !isTX / setReceiveBuffer + startReception -> S_RX_STARTING
      PFS.fired + isTX  / startTransmit(FSTXON) -> S_TX_STARTING
    
    S_RX_STARTING: setting up for cs/fs check
      phy.currentStatus(RX) / call FrameWaitAlarm.startAt(call FS.alarm(),
        fwCheckLen) -> S_RX_READY

    S_RX_READY: radio is in receive mode, frame has not yet started.
      phy.carrierSense / record time -> S_RX_READY
      FSCapture.captured() / signal frameStarted(call
        FSCapture.event()),  call FWA.stop() -> S_RECEIVING
      FWA.fired / resumeIdleMode -> S_IDLE

    S_RECEIVING: frame has started, expecting data.
      phy.receiveDone / post receiveTask -> S_RX_CLEANUP
      (cases where frame starts but we don't get data: same as S_IDLE)
      PFS.fired + !isTX / setReceiveBuffer + startReception -> S_RX_STARTING
      PFS.fired + isTX  / startTransmit(FSTXON) -> S_TX_STARTING
    
    S_RX_CLEANUP:
      receiveTask / signal receive + buffer swap 
        -> (phy.currentStatus)? [S_RX_READY, S_TX_READY]

    S_TX_STARTING:
      phy.currentStatus(FSTXON) / -> S_TX_READY 
    
    S_TX_READY:
      FS.fired / call phy.sendNow(signal TDMA.getPacket()) 
        -> S_TRANSMITTING
    
    S_TRANSMITTING:
      phy.sendDone / post sendDoneTask -> S_TX_CLEANUP

    S_TX_CLEANUP:
      sendDoneTask / signal send done 
        -> (phy.currentStatus)? [S_RX_READY, S_TX_READY]

    S_*_CLEANUP:
      *Task + dcOffPending + !scOffPending / call Resource.release +
        start dcTimer -> S_INACTIVE
      *Task + dcOffPending +  scOffPending / call Resource.release +
        stop timers -> S_OFF
    
    S_INACTIVE:
      dcTimer.fired() / call resource.request -> S_STARTING

    Other stuff:
      - splitcontrol.stop: set scOffPending
      - resource.granted: set dcTimer to turn off after last frame
      - dcTimer.fired: toggle dcOffPending, schedule to turn on prior
        to next period start

  */
  uint8_t state = S_OFF;

  command error_t CXTDMA.setSchedule(uint32_t startAt, 
      uint32_t frameLen, uint16_t numFrames, uint32_t csCheckLen,
      uint32_t fsCheckLen){
    call FrameAlarm.startAt(startAt, frameLen);
    //PREPARE_FRAME_SLACK: should be in the neighborhood of 90 uS (for
    //  transition from IDLE to RX or TX
    call PrepareFrameAlarm.startAt(startAt - PREPARE_FRAME_SLACK, frameLen);
    //TODO: on/off timer cycling as before
  }
  
  async event void PrepareFrameAlarm.fired(){
    error_t error;
    if (signal CXTDMA.isTXFrame(frameNum+1)){
      error = call Rf1aPhysical.startTransmission(FALSE);
      if (SUCCESS == error){
        //starts sending preamble: maybe we should just switch it into
        //  FSTXON. 
      } else{
        //TODO: handle error
      }
    } else {
      //set up radio for the next frame
      error = call Rf1aPhysical.setReceiveBuffer(rx_buffer, rx_len,
        TRUE, signal CXTDMA.isTXFrame(frameNum+2));
      if (SUCCESS == error){
        error = call Rf1aPhysical.startReception();
        if (SUCCESS == error){
          //TODO: set CS timeout
        } else {
          //TODO: handle error
        }
      } else {
        //TODO: handle error
      }
    }

    call PrepareFrameAlarm.startAt(call PrepareFrameAlarm.alarm(),
      frameLen);
  }

  message_t* curTX;
  uint8_t len;

  async event void FrameAlarm.fired(){
    frameNum++;
    if (checkState(S_TX_READY)){
      if (signal getPacket(&curTX, &len)){
        //TODO: if this is a TX frame, issue STX strobe. Set up for next
        //  frame
        call Rf1aPhysical.sendNow(curTX, len, 
          signal CXTDMA.isTXFrame(frameNum+1));
      } else {
        //TODO: abort transmission
      }
    }
    call FrameAlarm.startAt(call FrameAlarm.alarm(),
      frameLen);
  }
 
  command error_t SplitControl.start(){
    //TODO: request resource
    //TODO: calibrate if needed (should be done automatically)
    return FAIL;
  }

  command error_t SplitControl.stop (){
    //TODO: release resource
    return FAIL;
  }

  async event void Rf1aPhysical.carrierSense (){
    //TODO: set frameStart timeout
  }

  async event void Rf1aPhysical.receiveDone (uint8_t* buffer, unsigned
      int count, int result){
    //TODO: signal it up, with care.
  }

  async event void Rf1aPhysical.sendDone (int result) { 
    //TODO: signal it up, with care.
  }

  async event void Rf1aPhysical.frameStarted (){ 
    //Not used: use capture so that we get the correct time.
  }

  //TODO: frameStart timeout fired: switch radio to IDLE mode.
}
