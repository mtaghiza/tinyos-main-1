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

/**
 * Implementation of protocol-independent TDMA.
 *  - Duty cycling
 *  - request data at frame start
 */
 #include "CXTDMA.h"
 #include "CXTDMADebug.h"
 #include "CXTDMADispatchDebug.h"
 #include "SchedulerDebug.h"
 #include "TimingConstants.h"
 #include "Msp430Timer.h"
 #include "decodeError.h"

module CXTDMAPhysicalP {
  provides interface SplitControl;
  provides interface CXTDMA;
  provides interface TDMAPhySchedule;
  provides interface FrameStarted;

  provides interface Rf1aConfigure;
  uses interface Rf1aConfigure as SubRf1aConfigure[uint8_t sr];

  uses interface HplMsp430Rf1aIf;
  uses interface Resource;
  uses interface Rf1aPhysical;
  uses interface Rf1aPhysicalMetadata;
  uses interface Rf1aStatus;

  uses interface Rf1aPacket;
  //needed to set metadata fields of received packets
  uses interface Packet;
  uses interface CXPacket;
  uses interface CXPacketMetadata;

  uses interface Alarm<TMicro, uint32_t> as PrepareFrameStartAlarm;
  uses interface Alarm<TMicro, uint32_t> as FrameStartAlarm;
  uses interface Alarm<TMicro, uint32_t> as FrameWaitAlarm;
  uses interface GpioCapture as SynchCapture;

  uses interface Rf1aDumpConfig;
  uses interface StateTiming;
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
    S_INACTIVE = 0x02,
    S_IDLE = 0x03,
    S_STOPPING = 0x04,

    S_RX_STARTING = 0x10,
    S_RX_READY = 0x11,
    S_RECEIVING = 0x12,
    S_RX_CLEANUP = 0x13,

    S_TX_STARTING = 0x20,
    S_TX_READY = 0x21,
    S_TRANSMITTING = 0x22,
    S_TX_CLEANUP = 0x23,
  };
  
  uint8_t lastSched;
  uint32_t lastScheds[6];
  uint32_t schedSeqs[6];
  uint32_t schedSn = 0;

  uint32_t schedPFS;

  uint8_t state = S_OFF;
  
  //GpioCapture doesn't maintain this, we need it to differentiate
  //between the start-of-packet capture and end-of-packet capture
  uint8_t captureMode = MSP430TIMER_CM_NONE;
  
  //current frame in cycle
  uint16_t frameNum;
  //last point where we did a soft re-synch based on RX
  uint16_t resynchFrame;
  uint32_t rxResynchTime;

  //used to detect cases where frame setup does not get done in time:
  //  pfsPending: PFS was scheduled but not handled yet. FS should not
  //    find itself in a state that takes radio action.
  //  fsMissed: FS fired before we got to handle the PFS task: just
  //    reschedule and accept the missed frame start.
  bool pfsPending = FALSE;
  bool fsMissed = FALSE;

  //schedule variables
  uint32_t s_frameStart;
  uint32_t s_frameLen;
  uint32_t s_totalFrames;
  uint32_t s_fwCheckLen;
  uint8_t s_sr = SCHED_INIT_SYMBOLRATE;
  uint8_t s_sri = 0xff;
  uint8_t s_channel = TEST_CHANNEL;
  uint8_t s_isSynched = FALSE;

  //persist capture timings for cases where it must be recorded in a
  //later event
  uint32_t lastRECapture;
  uint32_t lastFECapture;

  //used for latching stop command to prepare-frame-start alarms
  bool scStopPending;
  error_t scStopError;

  //local buffer for received packets (swapped when signalling up)
  message_t rx_msg_internal;
  message_t* rx_msg = &rx_msg_internal;

  //pointer to currently-outstanding transmission: set when packet
  //retrieved from upper layer, cleared at sendDone from lower layer.
  message_t* tx_msg;
  
  //variables for various reports
  uint16_t sendCount = 0;
  //all access is in interrupt context
  norace uint16_t receiveCount = 0;
  uint16_t rxCaptureCount = 0;
  uint16_t txCaptureCount = 0;

  #if DEBUG_SYNCH_ADJUST == 1
  int32_t adjustments[64];
  uint16_t adjustmentFrames[64];
  uint8_t adjustmentCount = 0;
  #endif


  //async/race resolution vars
 
  //send-done: either the completeSend call in FrameStartAlarm.fired
  //  fails or we get a normal sendDone event from the physical layer.
  task void completeSendDone();
  norace uint16_t sdFrameNum;
  norace error_t sdResult;
  norace uint8_t sdLen;
  norace uint32_t sdTimestamp;
  norace message_t* sdMsg;
  bool sdPending;

  norace uint8_t* rdBuffer;
  norace unsigned int rdCount;
  norace int rdResult;
  norace bool rdS_sr;
  norace uint32_t rdLastRECapture;
  norace uint16_t rdFrameNum;
  bool rdPending;

  //protected by pfsPending
  norace uint16_t pfsFrameNum;

  //forward declarations
  bool getPacket(uint16_t fn);
  void completeCleanup();
  task void signalStopDone();
  task void debugConfig();
  bool checkState(uint8_t s);
  void setState(uint8_t s);
  bool inError();
  void stopTimers();
  task void reportStats();
  const char* decodeStatus();
  task void pfsTask();
  
 
  /***********************************
     MAIN LOGIC BELOW
   ***********************************/

  /**
   *  S_OFF: off/not duty cycled
   *    SplitControl.start / start capture + resource.request -> S_STARTING
   *  Other: EALREADY
   */ 
  command error_t SplitControl.start(){
    if (checkState(S_OFF)){
      atomic{
        captureMode = MSP430TIMER_CM_NONE;
        call SynchCapture.disable();
      }
      setState(S_STARTING);
      return call Resource.request();
    } else {
      return EALREADY;
    }
  }

  /**
   *  S_STARTING: radio core starting up/calibrating
   *   resource.granted / start timers  -> S_IDLE
   */
  event void Resource.granted(){
    if (checkState(S_STARTING)){
      setState(S_IDLE);
      post debugConfig();
      s_sri = srIndex(s_sr);
      signal SplitControl.startDone(SUCCESS);
    }
  }


  /**
   *  Indicates that a frame is going to be starting soon. At this
   *  point, upper layers will indicate whether or not they're going
   *  to use the radio (for RX or TX), and we set up the synch
   *  capture.
   *
   *  This should only fire when we're in S_IDLE.
   * 
   *  S_IDLE: in the part of a frame where no data is expected.
   *    scStopPending / call resource.release() -> S_STOPPING
   *    frameNum == activeFrames / call physical.sleep(), disable
   *      framestart alarm
   *      -> S_INACTIVE
   *    frameNum == 0 / call physical.resumeIdle()
   *      -> S_IDLE (continues)
   *    PFS.fired + !isTX / setReceiveBuffer + startReception + set
   *      next PrepareFrameStartAlarm + start capture
   *      -> S_RX_READY
   *    PFS.fired + isTX  / startTransmit(FSTXON), post getPacket task -> S_TX_READY
   *    All: schedule next PFS alarm based on s_frameLen and
   *      frameAdjustment from TDMAPhySchedule
   */
  async event void PrepareFrameStartAlarm.fired(){
    //increment frame number and then post a task which
    //does all the work outside of the interrupt context. the
    //only timing-critical code in here should be along the
    //FrameStartAlarm.fired path. 
    //It is important that we figure out what state to put the radio
    //in prior to the frameStartAlarm firing, though, and the tighter
    //we can make that timing, the more efficient this will be. So
    //maybe we should:
    //- pre-pfs.fired: at an undetermined point prior to frame-start: increment frame number
    //  and post task to figure out what we're going to do at the next
    //  frame boundary. In this task, set time for next alarm
    //- pfs.fired: this alarm should fire at a point dictated
    //  by the relevant setup time in the datasheet.  This should be
    //  as tight as we can make it.
    //- framestartalarm.fired: begin transmission (if TX), start
    //  timeout (if RX)
    if(call PrepareFrameStartAlarm.getNow() < call PrepareFrameStartAlarm.getAlarm()){
      printf_PFS_FREAKOUT("PFS EARLY (%lu < %lu)\r\n", call
      PrepareFrameStartAlarm.getNow(), call
      PrepareFrameStartAlarm.getAlarm());
      call PrepareFrameStartAlarm.startAt(
        call PrepareFrameStartAlarm.getAlarm() - s_frameLen, 
        s_frameLen);
      lastScheds[0] = call PrepareFrameStartAlarm.getAlarm();
      schedSeqs[0] = schedSn++;
      lastSched = 0;
      return;
    }
    if(frameNum & BIT0){
      PFS_CYCLE_CLEAR_PIN;
    }else{
      PFS_CYCLE_SET_PIN;
    }
    PFS_SET_PIN;
    frameNum = (frameNum + 1)%(s_totalFrames);
    atomic{
      if (!pfsPending){
        pfsFrameNum = frameNum;
        pfsPending = TRUE;
        post pfsTask();
      }
    }
  }

  task void pfsTask(){
    bool localFsMissed;
    error_t error;
    PFS_CYCLE_TOGGLE_PIN;
    PFS_CYCLE_TOGGLE_PIN;
    printf_PFS("*%u %lu (%lu)\r\n", frameNum, 
      call PrepareFrameStartAlarm.getNow(), 
      call PrepareFrameStartAlarm.getAlarm());
    atomic localFsMissed = fsMissed;
    if (!localFsMissed){
      if (scStopPending){
        scStopError = call Resource.release();
        if (SUCCESS == scStopError){
          stopTimers();
          scStopPending = FALSE;
          setState(S_STOPPING);
        } else{
          setState(S_ERROR_1);
        }
        post signalStopDone();
        PFS_CLEAR_PIN;
        atomic pfsPending = FALSE;
        return;
      }
      signal FrameStarted.frameStarted(pfsFrameNum);
      //0.5uS
      PFS_TOGGLE_PIN;
      
      if (pfsFrameNum == s_totalFrames - 1){
        post reportStats();
      }
  
      //TODO: transport duty cycle optimizations through here too
      //If we're currently not inactive, but this frame is unused, sleep
      //the radio.
      if (!checkState(S_INACTIVE) 
          && signal TDMAPhySchedule.isInactive(pfsFrameNum) ){
        if (SUCCESS == call Rf1aPhysical.sleep()){
          call FrameStartAlarm.stop();
          call FrameWaitAlarm.stop();
          FS_CYCLE_CLEAR_PIN;
          setState(S_INACTIVE);
        } else {
          setState(S_ERROR_1);
        }
      //If we're inactive, but this frame is used, wakeup the radio
      }else if (checkState(S_INACTIVE) 
          && ! signal TDMAPhySchedule.isInactive(pfsFrameNum)){
        if (SUCCESS == call Rf1aPhysical.resumeIdleMode()){
          call FrameStartAlarm.startAt(
            call PrepareFrameStartAlarm.getAlarm(), 
            PFS_SLACK);
          setState(S_IDLE);
        } else {
          setState(S_ERROR_2);
        }
      }

      //TODO: could post the below stuff in a second task. 
      //frameStarted is potentially a rather-long event to handle

      //Idle, or we are in an extra long frame-wait (e.g. trying to
      //  synch)
      if (checkState(S_IDLE) || checkState(S_RX_READY) 
          || checkState(S_RECEIVING)){
        //7.75 uS
        PFS_TOGGLE_PIN;
  
        IS_TX_CLEAR_PIN;
        switch(signal CXTDMA.frameType(pfsFrameNum)){
          case RF1A_OM_FSTXON:
            printf_SW_TOPO("F %u\r\n", pfsFrameNum);
            if (getPacket(pfsFrameNum)){
            IS_TX_SET_PIN;
            //0.75 uS
            PFS_TOGGLE_PIN;
            error = call Rf1aPhysical.startSend(FALSE, RF1A_OM_IDLE);
            //114 uS: when coming from idle, i guess this is OK. 
            PFS_TOGGLE_PIN;
            if (SUCCESS == error){
              setState(S_TX_READY);
            } else {
              printf("Error: %s\r\n", decodeError(error));
              setState(S_ERROR_f);
            }
            //2.75 uS
            PFS_TOGGLE_PIN;
    
            captureMode = MSP430TIMER_CM_RISING;
            call SynchCapture.captureRisingEdge();
            } else {
              printf("!Error: frameType FSTXON, but getPacket returned false\r\n");
  
            }
            break;
          case RF1A_OM_RX:
  //          printf_SW_TOPO("R %u\r\n", frameNum);
            //0.25 uS
            PFS_TOGGLE_PIN;
            error = call Rf1aPhysical.setReceiveBuffer(
              (uint8_t*)(rx_msg->header),
              TOSH_DATA_LENGTH + sizeof(message_header_t),
              RF1A_OM_IDLE);
            //11 uS
            PFS_TOGGLE_PIN;
            if (SUCCESS == error){
              atomic {
                captureMode = MSP430TIMER_CM_RISING;
                //0.75uS
                PFS_TOGGLE_PIN;
                call SynchCapture.captureRisingEdge();
                //7uS
                PFS_TOGGLE_PIN;
              }
              if (call Rf1aStatus.get() != RF1A_S_RX){
                printf_RXREADY_ERROR("! PFS.F RXREADY but radio %x\r\n", 
                  call Rf1aStatus.get() );
              }
              setState(S_RX_READY);
              RX_READY_SET_PIN;
            } else {
              printf("Error %s\r\n", decodeError(error));
              setState(S_ERROR_4);
            }
            //3.75 uS
            PFS_TOGGLE_PIN;
            break;
          default:
            setState(S_ERROR_1);
            atomic pfsPending = FALSE;
            return;
        }
      } else if (checkState(S_OFF)){
        //sometimes see this after wdtpw reset
        PFS_CLEAR_PIN;
        atomic pfsPending = FALSE;
        return;
      } else if (checkState(S_INACTIVE)){
        //nothing else to do, just reschedule alarm.
      } else {
        printf_TMP("!F %lu cs %lu s %lu\r\n",
          call PrepareFrameStartAlarm.getAlarm(), 
          rxResynchTime + s_frameLen-PFS_SLACK,
          schedPFS);
        setState(S_ERROR_5);
        return;
      }
    }else{
      printf_TMP("Missed FS\r\n");
    }
//    printf_TDMA_SS("pfs1\r\n");
//    printf_PFS("pfs1 %lu %lu: ", 
//      call PrepareFrameStartAlarm.getAlarm(), 
//      s_frameLen + signal TDMAPhySchedule.getFrameAdjustment(frameNum));
    call PrepareFrameStartAlarm.startAt(
      call PrepareFrameStartAlarm.getAlarm(), 
      s_frameLen );
    lastScheds[1] = call PrepareFrameStartAlarm.getAlarm();
      schedSeqs[1] = schedSn++;
    lastSched = 1;
//    printf_PFS("%lu\r\n",
//      call PrepareFrameStartAlarm.getAlarm());
    //16 uS
    PFS_SET_PIN;
    PFS_CLEAR_PIN;
    atomic {
      pfsPending = FALSE;
      fsMissed = FALSE;
    }
  }

  /**
   * S_RX_READY: radio is in receive mode, frame has not yet started.
   *    FWA.fired / resumeIdleMode -> S_IDLE
   */
  async event void FrameWaitAlarm.fired(){
    if (call FrameWaitAlarm.getNow() < call FrameWaitAlarm.getAlarm()){
      printf_PFS_FREAKOUT("FW EARLY");
      call FrameWaitAlarm.startAt(
        call FrameWaitAlarm.getAlarm() - s_frameLen, 
        s_frameLen);
      return;
    }
    FW_SET_PIN;
    FW_TOGGLE_PIN;
    if (checkState(S_RX_READY)){
      error_t error;
      RX_READY_CLEAR_PIN;
      error = call Rf1aPhysical.resumeIdleMode();
      FW_TOGGLE_PIN;
//      printf("T.O\r\n");
      if (error == SUCCESS){
        //resumeIdle alone seems to put us into a stuck state. not
        //  sure why. Radio stays in S_IDLE when we call
        //  setReceiveBuffer in pfs.f.
        //looks like this is firing when we are in the middle of a
        //receive sometimes: if this returns EBUSY, then we can assume
        //that and pretend it never happened (except that we called
        //resumeIdleMode above?
        error = call Rf1aPhysical.setReceiveBuffer(0, 0,
          RF1A_OM_IDLE);
        if (error == SUCCESS){
          setState(S_IDLE);
        } else {
          printf("!fwa.srb Error: %s\r\n", decodeError(error));
          setState(S_ERROR_3);
        }
      } else {
        setState(S_ERROR_6);
      }
      FW_TOGGLE_PIN;
    } else if(checkState(S_OFF)){
      FW_CLEAR_PIN;
      //sometimes see this after wdtpw reset
      return;
    } else {
      setState(S_ERROR_7);
    }
  }

  /**
   * Fires at the point where nodes believe their transmissions should
   * begin. When state is S_TX_READY, this means that everything up to
   * the completeSend command is timing-critical: it must be
   * deterministic between nodes and relatively short.
   *
   * S_RX_READY: radio is in receive mode, frame has not yet started.
   *    FrameStartAlarm.fired / start frameWaitAlarm -> S_RX_READY
   *
   * S_TX_READY:
   *    FS.fired / call phy.completeSend
   *      -> S_TRANSMITTING
   *
   */
  async event void FrameStartAlarm.fired(){
    error_t error;
    uint32_t lastFsa;

    if (frameNum & BIT0){
      FS_CYCLE_CLEAR_PIN;
    }else{
      FS_CYCLE_SET_PIN;
    }
    //indicates that we did not handle the setup yet for this frame.
    //So, the pfs task should *not* run as usual (should just
    //reschedule and move on).
    if (pfsPending){
      fsMissed = TRUE;
    }

    //0.25 uS
    TX_SET_PIN;
    FS_SET_PIN;
    if (checkState(S_TX_READY)){
      FS_STROBE_SET_PIN;
      TXCP_SET_PIN;
      FS_TOGGLE_PIN;
      //4 uS
      TX_TOGGLE_PIN;
      error = call Rf1aPhysical.completeSend();
      //6.25 uS (+ 68.25 uS)
      TX_TOGGLE_PIN;
      TX_CLEAR_PIN;
      TX_SET_PIN;
      TX_CLEAR_PIN;
      if (SUCCESS == error){
        //66.25 uS: OK, this is time to load FIFO.
        FS_TOGGLE_PIN;
        setState(S_TRANSMITTING);
        //3.75 uS
        FS_TOGGLE_PIN;
      } else {
        error = call Rf1aPhysical.resumeIdleMode();
      }
      //0.5 uS
      FS_TOGGLE_PIN;
      if (SUCCESS != error){
        if (!sdPending){
          sdPending = TRUE;
          sdMsg = tx_msg;
          sdLen = 0;
          sdFrameNum = frameNum;
          sdResult = error;
          post completeSendDone();
        }else{
          setState(S_ERROR_f);
        }
      }
      //0.5 uS
      FS_TOGGLE_PIN;
    } else if (checkState(S_RX_READY)){
      if (call Rf1aStatus.get() != RF1A_S_RX){
        printf_RXREADY_ERROR("! FS.F RXREADY but radio %x\r\n", call Rf1aStatus.get());
      }
      //4 uS to here
      FS_TOGGLE_PIN;
      call FrameWaitAlarm.stop();
      //1.25 uS 
      FS_TOGGLE_PIN;
      call FrameWaitAlarm.startAt(call FrameStartAlarm.getAlarm(),
        s_fwCheckLen);
//      printf("FS %s\r\n", decodeStatus());
      //14.25 uS 
      FS_TOGGLE_PIN;
    } else if (checkState(S_OFF)){ 
      //sometimes see this after wdtpw reset
      FS_CLEAR_PIN;
      TX_CLEAR_PIN;
      return;
    } else if(checkState(S_RECEIVING)){
      //This happens when trying to latch on to the schedule
      //sometimes. Basically, frameStartAlarm is not lined up with the
      //true schedule so it can fire in the middle of a packet
      //reception. In this case, just ignore it, we should get a good
      //schedule soon.
    }  else {

      //would rather do this up top, but getNow introduces a TON of
      //jitter.
      if(call FrameStartAlarm.getNow() < call FrameStartAlarm.getAlarm()){
        printf_PFS_FREAKOUT("FS EARLY");
        call FrameStartAlarm.startAt(
          call FrameStartAlarm.getAlarm() - s_frameLen, 
          s_frameLen);
        return;
      } else if (checkState(S_IDLE)){
      //It seems like the framewait alarm can fire before framestart
      //alarm and that puts us into idle-- don't know how this can
      //happen. I guess it could also be possible that, due to atomic
      //blocks or something, PFS and FS are both in a state where they
      //are trying to fire, and we sometimes handle FS first. 

      //either way, let's just ignore it and hope that it resolves
      //itself.
      printf_TMP("!FSA.F\r\n");
      FS_CYCLE_TOGGLE_PIN;
      FS_CYCLE_TOGGLE_PIN;

      } else if (checkState(S_INACTIVE)){
        //happens when we lose synch: we'll pick it up again
        //momentarily
        printf("!Inactive fsa.f\r\n");
        return;
      } else{
        printf("!Error @fn %u\r\n", frameNum);
        setState(S_ERROR_8);
      }
    }
    lastFsa = call FrameStartAlarm.getAlarm();
    //0.5 uS
    FS_TOGGLE_PIN;
    if (! inError()){
      call FrameStartAlarm.startAt(lastFsa,
        s_frameLen );
    }
    //16 uS
    FS_SET_PIN;
    FS_CLEAR_PIN;
    TX_CLEAR_PIN;
  }


  bool gpResult;
  uint16_t tx_len;
  

  //retrieve packet from upper layer and store it here until requested
  //from phy.
  bool getPacket(uint16_t fn){
    uint8_t* gpBufLocal;
    uint16_t gpLenLocal;
    bool gpResultLocal;
    message_t* tx_msgLocal;

    atomic gpResult = FALSE;

    gpResultLocal = signal CXTDMA.getPacket((message_t**)(&gpBufLocal), fn);
    tx_msgLocal = (message_t*)(gpBufLocal);
    //set the tx timestamp if we are the origin
    //  and this is the first transmission.
    //This looks a little funny, but we're trying to make sure that
    //the same instructions are executed whether we write a new
    //timestamp or not, so that we can maintain synchronization
    //between the origin and the forwarder.
    if (tx_msgLocal != NULL){
      gpLenLocal = (call Rf1aPacket.metadata(tx_msgLocal))->payload_length;
      call CXPacket.incCount(tx_msgLocal);
      {
        bool amSource = call CXPacket.source(tx_msgLocal) == TOS_NODE_ID;
        bool isFirst = call CXPacket.count(tx_msgLocal) == 1;
        uint32_t lastAlarm = call FrameStartAlarm.getAlarm();
        uint32_t curTimestamp = call CXPacket.getTimestamp(tx_msgLocal);
        uint8_t curSN = call CXPacket.getScheduleNum(tx_msgLocal);
        uint8_t mySN = signal TDMAPhySchedule.getScheduleNum();
        uint16_t curOF = call CXPacket.getOriginalFrameNum(tx_msgLocal);
        bool lastSentOrigin = amSource && isFirst;
        //lastAlarm *should* be valid, AFAIK, since FSA is already set
        //up at this point.
        #if DEBUG_FEC == 1
        call CXPacket.setTimestamp(tx_msgLocal, 
          lastSentOrigin? 0xdeadbeef : curTimestamp);
        #else
  //      call CXPacket.setTimestamp(tx_msgLocal, 
  //        lastSentOrigin? 0xdeadbeef : curTimestamp);
        call CXPacket.setTimestamp(tx_msgLocal, 
          lastSentOrigin? lastAlarm : curTimestamp);
        #endif
        call CXPacket.setScheduleNum(tx_msgLocal,
          lastSentOrigin? mySN: curSN);
        call CXPacket.setOriginalFrameNum(tx_msgLocal,
          lastSentOrigin? fn: curOF);
      }
    }
//    printf_TMP("buf: %p len: %u\r\n", gpBuf, gpLen);
    atomic{
      tx_msg = (message_t*)tx_msgLocal;
      tx_len = gpLenLocal;
      gpResult = gpResultLocal;
    }
    return gpResultLocal;
  }

  //give back pointers to the most-recently-cached TX packet from
  //upper layers.
  async event bool Rf1aPhysical.getPacket(uint8_t** buffer, 
      uint8_t* len){
    *buffer = (uint8_t*)tx_msg;
    *len = tx_len;
    return gpResult;
  }

  uint32_t resynchFrameStart;
   
  task void debugTxResynch(){
    printf_TMP("TXR %lu\r\n", call PrepareFrameStartAlarm.getAlarm());
  }

  //set frame start alarm and prepare frame start alarm in response to
  //a resynchronization event (either starting to send a packet, or
  //upon successful reception of a packet).
  void resynch(){
//    post debugTxResynch();
    atomic{
      call PrepareFrameStartAlarm.startAt(resynchFrameStart, s_frameLen - PFS_SLACK);
      lastScheds[2] = call PrepareFrameStartAlarm.getAlarm();
      schedSeqs[2] = schedSn++;
      lastSched = 2;
      call FrameStartAlarm.startAt(resynchFrameStart, s_frameLen);
    }
  }

  void rxResynch(uint32_t fs){
    atomic{
      call PrepareFrameStartAlarm.startAt(fs, s_frameLen - PFS_SLACK);
      lastScheds[3] = call PrepareFrameStartAlarm.getAlarm();
      schedSeqs[3] = schedSn++;
      lastSched = 3;
      call FrameStartAlarm.startAt(fs, s_frameLen);
    
      if (call PrepareFrameStartAlarm.getAlarm() != fs + (s_frameLen - PFS_SLACK)){
        printf("!PFS set failure: ga %lu != %lu\r\n", 
          call PrepareFrameStartAlarm.getAlarm(), 
          fs + (s_frameLen - PFS_SLACK));
      }
      if (call FrameStartAlarm.getAlarm() != (fs + s_frameLen) ){
        printf("!FS set failure: ga %lu != %lu\r\n", 
          call FrameStartAlarm.getAlarm(), 
          fs + s_frameLen);
      }
      schedPFS = call PrepareFrameStartAlarm.getAlarm();
    }
  }

  task void reportCorrectOverflow(){
    printf_TMP("!COF\r\n");
  }

  /**
   * Indicates a packet start/end capture from the radio. We use this
   * to synch to the frame edges (immediately if in TX, deferred until
   * CRC passed if in RX).
   *
   * S_RX_READY: radio is in receive mode, frame has not yet started.
   *   SynchCapture.captured() /  call FWA.stop() -> S_RECEIVING
   * S_TRANSMITTING: our own start-of-packet
   *   SynchCapture.captured() / adjust alarms -> S_TRANSMITTING
   */
  async event void SynchCapture.captured(uint16_t time){
    uint32_t fst; 
    uint32_t capture;

    SC_SET_PIN;
    fst = call FrameStartAlarm.getNow();

    //to put into 32-bit time scale, keep upper 16 bits of 32-bit
    //  counter. 
    //correct for overflow: will be visible if the capture time is
    //  larger than the current lower 16 bits of the 32-bit counter.
    //  This assumes that the 16-bit synch capture timer overflows at
    //  most once before this event runs (hopefully true, about 10 ms
    //  at 6.5 Mhz)
    if (time > (fst & 0x0000ffff)){
      post reportCorrectOverflow();
      SYNCH_SET_PIN;
      fst  -= 0x00010000;
      SYNCH_CLEAR_PIN;
    } 
    capture = (fst & 0xffff0000) | time;
    //1 uS
    SC_TOGGLE_PIN;

    if (captureMode == MSP430TIMER_CM_RISING){
      if (tx_msg != NULL && call CXPacket.source(tx_msg) == TOS_NODE_ID){
        printf_PHY_TIME("T@ %lu %u\r\n", capture, frameNum);
      }
      
      //1 uS
      lastRECapture = capture;
      SC_TOGGLE_PIN;
      atomic{
        captureMode = MSP430TIMER_CM_FALLING;
        call SynchCapture.captureFallingEdge();
      }
      //6.5 uS
      SC_TOGGLE_PIN;
      if (checkState(S_RX_READY)){
        //just received a packet. let's adjust our alarms!
        uint32_t thisFrameStart = capture 
          - sfdDelays[s_sri] 
          - fsDelays[s_sri];
//          - tuningDelays[s_sri];
        rxCaptureCount++;
        #if DEBUG_SYNCH_ADJUSTMENTS == 1
        adjustments[adjustmentCount] = thisFrameStart - (call FrameStartAlarm.getAlarm() - s_frameLen);
        #endif
        //Wait until CRC is validated before reysnching.
        RESYNCH_SET_PIN;
        resynchFrameStart = thisFrameStart;
        rxResynchTime = resynchFrameStart;
        call FrameWaitAlarm.stop();

        #if DEBUG_SYNCH_ADJUSTMENTS == 1
        adjustmentFrames[adjustmentCount] = frameNum;
        adjustmentCount = (adjustmentCount + 1) %64;
        #endif
        setState(S_RECEIVING);
      } else if (checkState(S_TRANSMITTING)){
        //adjust self to compensate for jitter introduced by
        //interrupt handling.
        uint32_t thisFrameStart = capture 
          - fsDelays[s_sri];
//          - tuningDelays[s_sri];
        #if DEBUG_SYNCH_ADJUSTMENTS == 1
        adjustments[adjustmentCount] = thisFrameStart - (call FrameStartAlarm.getAlarm() - s_frameLen);
        #endif
        txCaptureCount++;
//        if (lastSentOrigin){
//          //TODO: see if this holds constant across different nodes.
//          //   300 -> 301 -> 302 , originDelay = 0 retx2_noadjust.csv
//          //     1.0e-6  -1.7e-7
//          //   300 -> 301 -> 302 , originDelay = 7 retx2.csv
//          //     1.3e-7  7.3e-7
//          //   301 -> 300 -> 302 , originDelay = 7 retx2_swap.csv
//          //    -2.1e-7  1.0e-6
//          //   301 -> 300 -> 302 , originDelay = 0 retx2_swap_noadjust.csv
//          //    1.1e-6   1.2e-6
//          thisFrameStart += originDelays[s_sri];
//        }
        resynchFrameStart = thisFrameStart;
        resynch();
        call FrameWaitAlarm.stop();
        #if DEBUG_SYNCH_ADJUSTMENTS == 1
        adjustmentFrames[adjustmentCount] = frameNum;
        adjustmentCount = (adjustmentCount + 1) %64;
        #endif
      } else {
        setState(S_ERROR_9);
      }
      //7 uS
      SC_TOGGLE_PIN;
    } else if (captureMode == MSP430TIMER_CM_FALLING){
      //Note: this is currently unused. Is there any benefit to
      //recording packet duration?
      lastFECapture = capture;
      atomic{
        captureMode = MSP430TIMER_CM_NONE;
        call SynchCapture.disable();
      }
    } else if (checkState(S_OFF)){
      //sometimes see this after wdtpw reset
      SC_CLEAR_PIN;
      return;
    } else {
      setState(S_ERROR_a);
    }
    //0.75 uS
    SC_SET_PIN;
    SC_CLEAR_PIN;
  }

  /**
   *  Synch this layer's state with radio core. 
   */ 
  void completeCleanup(){
    //we see a state of RF1A_S_SETTLING if we're doing an automatic switch from RX to FSTXON
    //or from FSTXON to RX.
    //we see a state of RF1A_S_TX if we are transmitting at a low
    //symbol rate (last byte clears the fifo and we get the sendDone
    //  etc. before it has actually finished transmitting it).
    while(call Rf1aStatus.get() == RF1A_S_SETTLING 
      || call Rf1aStatus.get() == RF1A_S_TX){ };
    switch (call Rf1aStatus.get()){
      case RF1A_S_IDLE:
        //if we're not synched, then we need to set ourselves
        //back up for RX.  
        setState(S_IDLE);
        if (! s_isSynched){
          uint32_t rp = call PrepareFrameStartAlarm.getNow();
          call PrepareFrameStartAlarm.stop();
          call FrameStartAlarm.stop();
          //TODO: is this where the alarm is getting reset to the
          //wrong time?
          call PrepareFrameStartAlarm.startAt(rp - PFS_SLACK,
            2*PFS_SLACK);
          lastScheds[4] = call PrepareFrameStartAlarm.getAlarm();
      schedSeqs[4] = schedSn++;
          lastSched = 4;
          call FrameStartAlarm.startAt(rp - PFS_SLACK,
            3*PFS_SLACK);
        }
        break;
      case RF1A_S_RX:
//        printf("0");
        setState(S_RX_READY);
        break;
      case RF1A_S_FSTXON:
        setState(S_TX_READY);
        break;
      default:
        printf("cleanup in state %s\r\n", decodeStatus());
        setState(S_ERROR_b);
    }
  }
  
  uint8_t lastRxBuf[64];
  uint8_t lastRxLen;
  bool lastRxBufBusy;
  task void printLastRx(){
    uint8_t i;
    printf("R ");
    for (i = 0; i < lastRxLen; i++){
      printf("%02X ",lastRxBuf[i]);
    }
    printf("\r\n");
    lastRxBufBusy = FALSE;
  }

  task void reportResynch(){
    signal TDMAPhySchedule.resynched(resynchFrame);
  }


  task void completeReceiveDone(){
    if(checkState(S_RECEIVING)){
      if (SUCCESS == rdResult){
        message_t* msg = (message_t*)rdBuffer;
        setState(S_RX_CLEANUP);
        //count includes the header length, so we need to subtract it
        //here.
        call Packet.setPayloadLength(msg,
          rdCount-sizeof(message_header_t));
        if (call Rf1aPacket.crcPassed(msg)){

          receiveCount++;
            //Nope, this is done during the TX process.
  //          call CXPacket.setCount((message_t*)buffer, 
  //            call CXPacket.count((message_t*)buffer) +1);
          printf_PHY_TIME("R@ %lu %u\r\n", rdLastRECapture, rdFrameNum);
          call CXPacketMetadata.setSymbolRate(msg,
            rdS_sr);
          printf_PHY_TIME("set phy\r\n");
          call CXPacketMetadata.setPhyTimestamp(msg,
            rdLastRECapture);
          call CXPacketMetadata.setFrameNum(msg,
            rdFrameNum);
          call CXPacketMetadata.setReceivedCount(msg,
            call CXPacket.count(msg));
          if (call Rf1aPacket.crcPassed(msg) 
              && call CXPacket.getScheduleNum(msg) == signal TDMAPhySchedule.getScheduleNum()){
            resynchFrame = frameNum;
//              resynch();
            rxResynch(rxResynchTime);
            RESYNCH_CLEAR_PIN;
            if (rxResynchTime != resynchFrameStart){
              setState(S_ERROR_f);
            }
            post reportResynch();
          } 
          rx_msg = signal CXTDMA.receive(msg, 
            rdCount - sizeof(rf1a_ieee154_t),
            rdFrameNum, rdLastRECapture);
        } else {
          printf_TESTBED_CRC("R! %u\r\n", frameNum);
        }
        completeCleanup();
      } else if (ENOMEM == rdResult){
        //this gives ENOMEM if we don't receive the entire packet, I
        //guess due to interference or something? 
        //anyway, nothing to be done about it so just clean up.
        setState(S_RX_CLEANUP);
        completeCleanup();
      } else if (ECANCEL == rdResult){
        //RXFIFO overflow leads to this (happens if the length field
        //is corrupted/too long, for instance).
        setState(S_RX_CLEANUP);
        completeCleanup();
      } else {
//        printf_TESTBED("!\r\n");
        printf("Phy.receiveDone: %s\r\n", decodeError(rdResult));
        setState(S_ERROR_c);
      }
    }
    atomic rdPending = FALSE;
  }

  /**
   * S_RECEIVING: frame has started, expecting data.
   *   phy.receiveDone / signal and swap -> S_RX_CLEANUP
   */
  async event void Rf1aPhysical.receiveDone (uint8_t* buffer,
                                             unsigned int count,
                                             int result) {
    //this is only ever signalled from interrupt context, so it
    //doesn't really need to be atomic. but otherwise the compiler
    //complains about access to rdPending.
    atomic{
      if (checkState(S_RECEIVING)){
        if (!rdPending){
          rdBuffer = buffer;
          rdCount = count;
          rdResult = result;
          rdS_sr = s_sr;
          rdLastRECapture = lastRECapture;
          rdFrameNum = frameNum;
    
          //These should be done immediately: store radio metadata, resynch
          //  alarms
          if (checkState(S_RECEIVING) && result == SUCCESS){
            message_t* msg = (message_t*) buffer;
            message_metadata_t* mmd = (message_metadata_t*)(&(msg->metadata));
            rf1a_metadata_t* rf1aMD = &(mmd->rf1a);
            call Rf1aPhysicalMetadata.store(rf1aMD);
    
//            if (call Rf1aPacket.crcPassed(msg) 
//                && call CXPacket.getScheduleNum(msg) == signal TDMAPhySchedule.getScheduleNum()){
//              resynchFrame = frameNum;
////              resynch();
//              rxResynch(rxResynchTime);
//              RESYNCH_CLEAR_PIN;
//              if (rxResynchTime != resynchFrameStart){
//                setState(S_ERROR_f);
//              }
//              post reportResynch();
//            } 
          }
          rdPending = TRUE;
          post completeReceiveDone();
        } else {
          setState(S_ERROR_f);
        }
      
      }else if (checkState(S_RX_READY)){
        //ignore it, we got a packet but didn't get the SFD event so we
        //can't timestamp it.
      } else {
        setState(S_ERROR_d);
      }
    }
  }

  

  task void completeSendDone();

  /**
   * S_TRANSMITTING:
   *   phy.sendDone / signal sendDone, set phy timestamp if origin -> S_TX_CLEANUP 
   */
  async event void Rf1aPhysical.sendDone (uint8_t* buffer, 
      uint8_t len, int result) { 
    sendCount++;
    if(checkState(S_TRANSMITTING) && ! sdPending && (message_t*)buffer == tx_msg){
      sdPending = TRUE;
      sdFrameNum = frameNum;
      sdResult = result;
      sdLen = len;
      sdMsg = tx_msg;
      tx_msg = NULL;
      setState(S_TX_CLEANUP);
      post completeSendDone();
    } else {
      setState(S_ERROR_e);
    }
  }

  task void completeSendDone(){
    if (checkState(S_TX_CLEANUP)){
      completeCleanup();
  
      //set the phy timestamp if we are the source and this is the
      //first time we've sent it.
      if ( call CXPacket.source(sdMsg) == TOS_NODE_ID 
          && call CXPacket.count(sdMsg) == 1){
        printf_PHY_TIME("set phy\r\n");
        call CXPacketMetadata.setPhyTimestamp(sdMsg,
          sdTimestamp);
      }
      signal CXTDMA.sendDone(sdMsg, sdLen, sdFrameNum, sdResult);

      atomic sdPending = FALSE;
    }
  }

  command error_t SplitControl.stop(){
    atomic scStopPending = TRUE; 
    return SUCCESS;
  }

  task void signalStopDone(){
    error_t error;
    atomic error = scStopError;
    setState(S_OFF);
    signal SplitControl.stopDone(error);
  }

  async command uint32_t TDMAPhySchedule.getNow(){
    return call FrameStartAlarm.getNow();
  }

 
  //Update schedule parameters, taking care to handle missed alarms.
  command error_t TDMAPhySchedule.setSchedule(uint32_t startAt,
      uint16_t atFrameNum, uint16_t totalFrames, uint8_t symbolRate, 
      uint8_t channel, bool isSynched){
    printf_TMP("SS\r\n");
//    post debugConfig();
    SS_SET_PIN;
    if (checkState(S_RECEIVING) || checkState(S_TRANSMITTING)){
      SS_CLEAR_PIN;
      //would be nicer to buffer the new settings and apply them when
      //it's safe.
      return ERETRY;
    } else if(checkState(S_OFF)){
      SS_CLEAR_PIN;
      return EOFF;
    } else if(!inError()) {
      uint32_t pfsStartAt;
      uint32_t delta;
      uint8_t last_sr;
      uint8_t last_channel;
      call PrepareFrameStartAlarm.stop();
      call FrameStartAlarm.stop();
      call SynchCapture.disable();
      printf_TDMA_SS("SS@ %lu: %lu %u %u %u %u\r\n", 
        call FrameStartAlarm.getNow(), 
        startAt, 
        atFrameNum,
        totalFrames,
        symbolRate, 
        channel);
      atomic{
        last_sr = s_sr;
        last_channel = s_channel;
        s_totalFrames = totalFrames;
        s_sr = symbolRate;
        s_sri = srIndex(s_sr);
        s_frameLen = frameLens[s_sri];
        s_fwCheckLen = fwCheckLens[s_sri];

        //not synched: set the frame wait timeout to 2x frame len
        if (!isSynched){
          s_frameLen *= 10;
          s_fwCheckLen = 2*s_frameLen;
        }

        //while target frameStart is in the past
        // - add 1 to target frameNum, add framelen to target frameStart
        //TODO: fix issue with PFS_SLACK causing numbers to wrap
        pfsStartAt = startAt - PFS_SLACK ;
        while (pfsStartAt < call PrepareFrameStartAlarm.getNow()){
          pfsStartAt += s_frameLen;
          atFrameNum = (atFrameNum + 1)%(s_totalFrames);
        }

        //now that target is in the future: 
        //  - set frameNum to target framenum - 1 (so that pfs counts to
        //    correct frame num when it fires).
        if (atFrameNum == 0){
          frameNum = s_totalFrames;
        }else{
          frameNum = atFrameNum - 1;
        }
        //  - set base and delta to arbitrary values s.t. base +delta =
        //    target frame start
        delta = call PrepareFrameStartAlarm.getNow();
        call PrepareFrameStartAlarm.startAt(pfsStartAt-delta,
          delta);
        lastScheds[5] = call PrepareFrameStartAlarm.getAlarm();
      schedSeqs[5] = schedSn++;
        lastSched = 5;
        call FrameStartAlarm.startAt(pfsStartAt-delta,
          delta + PFS_SLACK);
  
        s_frameStart = startAt;
        s_isSynched = isSynched;
      }
      //If channel or symbol rate changes, need to reconfigure
      //  radio.
      if (s_sr != last_sr || s_channel != last_channel){
        call Rf1aPhysical.reconfigure();
      }
 
      //TODO: check for over/under flows
//      printf_TDMA_SS("Now %lu base %lu delta %lu (%lu %lu) at %u\r\n", 
//        call PrepareFrameStartAlarm.getNow(), s_frameStart,
//        firstDelta, 
//        firstDelta-PFS_SLACK-SFD_TIME, 
//        firstDelta - SFD_TIME, 
//        frameNum);
//
  
      printf_TDMA_SS("GA: %lu (%u)\r\n", 
        call PrepareFrameStartAlarm.getAlarm(), frameNum);
      return SUCCESS;
    } else {
      setState(S_ERROR_2);
      SS_CLEAR_PIN;
      return FAIL;
    }
  }

  async event uint8_t Rf1aPhysical.getChannelToUse(){
    return s_channel;
  }
  
  //configuration is determined by dispatching to current
  //symbol rate's config
  async command const rf1a_config_t* Rf1aConfigure.getConfiguration(){
    printf_SCHED_SR("Get configuration: %u\r\n", s_sr);
    return call SubRf1aConfigure.getConfiguration[s_sr]();
  }

  async command void Rf1aConfigure.preConfigure (){ }
  async command void Rf1aConfigure.postConfigure (){ }
  async command void Rf1aConfigure.preUnconfigure (){}
  async command void Rf1aConfigure.postUnconfigure (){}

  default async command void SubRf1aConfigure.preConfigure [uint8_t client](){ }
  default async command void SubRf1aConfigure.postConfigure [uint8_t client](){}
  default async command void SubRf1aConfigure.preUnconfigure [uint8_t client](){}
  default async command void SubRf1aConfigure.postUnconfigure [uint8_t client](){}


  default async command const rf1a_config_t* SubRf1aConfigure.getConfiguration[uint8_t client] ()
  {
    printf("CXTDMAPhysicalP: Unknown sr requested: %u\r\n", client);
    return call SubRf1aConfigure.getConfiguration[1]();
  }


  async event void Rf1aPhysical.frameStarted () { 
    //ignored: we use the GDO timer capture for this.
  }

  //BEGIN unused
  async event void Rf1aPhysical.carrierSense () { }
  async event void Rf1aPhysical.receiveStarted (unsigned int length) { }
  async event void Rf1aPhysical.receiveBufferFilled (uint8_t* buffer,
                                                     unsigned int count) { }
  async event void Rf1aPhysical.clearChannel () { }
  async event void Rf1aPhysical.released () { }

  async event bool Rf1aPhysical.idleModeRx () { 
    return FALSE;
  }
  //END unimplemented

  /************
    status-reporting/debug below
  ************/
  const char* decodeStatus(){
    switch(call Rf1aStatus.get()){
      case RF1A_S_IDLE:
        return "S_IDLE";
      case RF1A_S_RX:
        return "S_RX";
      case RF1A_S_TX:
        return "S_TX";
      case RF1A_S_FSTXON:
        return "S_FSTXON";
      case RF1A_S_CALIBRATE:
        return "S_CALIBRATE";
      case RF1A_S_FIFOMASK:
        return "S_FIFOMASK";
      case RF1A_S_SETTLING:
        return "S_SETTLING";
      case RF1A_S_RXFIFO_OVERFLOW:
        return "S_RXFIFO_OVERFLOW";
      case RF1A_S_TXFIFO_UNDERFLOW:
        return "S_TXFIFO_UNDERFLOW";
      case RF1A_S_OFFLINE:
        return "S_OFFLINE";
      default:
        return "???";
    }
  }

  void printStatus(){
    printf("* Core: %s\r\n", decodeStatus());
    printf("--------\r\n");
  }

  task void printStatusTask(){
    printStatus();
  }
 
  task void debugConfig(){
    #if DEBUG_CONFIG == 1
    rf1a_config_t config;
    call Rf1aPhysical.readConfiguration(&config);
    call Rf1aDumpConfig.display(&config);
    #endif
  } 

  //stop all timers: used at error or when shutting down the
  //component.
  void stopTimers(){
    call PrepareFrameStartAlarm.stop();
    call FrameStartAlarm.stop();
    call FrameWaitAlarm.stop();
    call SynchCapture.disable();
  }
  
  task void printScheds(){
    uint8_t i;
    atomic{
      printf_TMP("Last Sched: %u\r\n", lastSched);
      printf_TMP("Last alarm: %lu\r\n", 
        call PrepareFrameStartAlarm.getAlarm());
      printf_TMP("FL: %lu FL-slack: %lu 2slack: %lu\r\n", 
        s_frameLen, s_frameLen - PFS_SLACK, 2*PFS_SLACK);
      for (i = 0; i < 5; i++){
        printf_TMP("PFS %u: %lu %lu\r\n", i, schedSeqs[i], lastScheds[i]);
      }
    }
  }

  //convenience state manipulation functions
  bool checkState(uint8_t s){ atomic return (state == s); }
  void setState(uint8_t s){
    atomic {
      if (state == s){
        return;
      }
      #ifdef DEBUG_CX_TDMA_P_STATE_IDLE
      if (s == S_IDLE){
        printf("[%x->%x]\r\n", state, s);
      }
      #endif
      #ifdef DEBUG_CX_TDMA_P_STATE
      printf("[%x->%x]\r\n", state, s);
      #endif
      #ifdef DEBUG_CX_TDMA_P_STATE_ERROR
      if (ERROR_MASK == (s & ERROR_MASK)){
        P2OUT |= BIT4;
        stopTimers();
        printf("!ERR [%x->%x]\r\n", state, s);
        post printScheds();
      }
      #endif
      state = s;
    }
  }

  bool inError(){
    atomic return (ERROR_MASK & state);
  }

  //Reporting functions
  uint32_t reportNum;

  task void reportStats(){
    REPORT_STATS_TOGGLE_PIN;
    printf_RADIO_STATS("PC %lu Sent %u Received %u tx cap %u rx cap %u\r\n", reportNum, sendCount,
      receiveCount, txCaptureCount, rxCaptureCount);
//    {
//    uint8_t rs;
////    for (rs = 0x00; rs <= 0x80; rs+= 0x10){
////      uint32_t overflows = call StateTiming.getOverflows(rs);
////      uint32_t cur = call StateTiming.getTotal(rs);
////      printf_RADIO_STATS("RS %lu %x %lu %lu\r\n", 
////        reportNum, rs, 
////        overflows, cur);
////    }
//    }
    reportNum++;
    #if DEBUG_SYNCH_ADJUST == 1
    {
      uint8_t i;
      for (i = 0; i < adjustmentCount; i++){
        printf_SYNCH_ADJUST("ADJUST %u %ld\r\n", adjustmentFrames[i],
          adjustments[i]);
      }
    }
    adjustmentCount = 0;
    #endif
//    printf_RADIO_STATS("xt2Counted = sum([");
//    for (rs = 0x00; rs <= 0x80; rs+= 0x10){
//      printf_RADIO_STATS("%lu, ", call StateTiming.getTotal(rs));
//    }
//    printf_RADIO_STATS("])/(26e6/4)\r\n");
//    printf_RADIO_STATS("xt2Total = (%lu )/(26e6/4)\r\n",
//      thisReport);
////    printf_RADIO_STATS("xt2Counted\r\n");
////    printf_RADIO_STATS("xt2Total\r\n");
//    printf_RADIO_STATS("print (xt2Counted - xt2Total), xt2Counted, xt2Total\r\n");
////    lastReport = thisReport;
  } 

 }
/* 
 * Local Variables:
 * mode: c
 * End:
 */
