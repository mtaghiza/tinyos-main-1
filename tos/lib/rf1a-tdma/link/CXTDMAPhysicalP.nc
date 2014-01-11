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
  
  #if DEBUG_CONFIG == 1
  uses interface Rf1aDumpConfig;
  #endif

  uses interface StateTiming;

  uses interface Random;

  uses interface DelayedSend;
  provides interface Rf1aTransmitFragment;

  //TODO: need setChannel (either add it to TDMAPhySchedule interface
  //or add it as Set/Get interfaces
} implementation {

  uint32_t lastFsa;

  task void setTimestamp();
  
  #define PFS_HISTORY_LEN 4
  uint32_t pfsHistory[PFS_HISTORY_LEN];
  uint8_t pfsSetByHistory[PFS_HISTORY_LEN];
  uint8_t pfsPos = 0;

  void recordPfs(uint8_t setBy){
    atomic{
      pfsHistory[pfsPos] = call PrepareFrameStartAlarm.getAlarm();;
      pfsSetByHistory[pfsPos] = setBy;
      pfsPos = (pfsPos + 1) % PFS_HISTORY_LEN;
    }
  }

  void printPfsHistory(){
    atomic{
      uint8_t c;
      printf("# PFS History\r\n");
      for (c = 0; c < PFS_HISTORY_LEN; c++){
        uint8_t i = (c + pfsPos) % PFS_HISTORY_LEN;
        printf("# by %u : %lu\r\n", 
          pfsSetByHistory[i],
          pfsHistory[i]);
      }
    }
  }

  task void printPfsHistoryTask(){
    printPfsHistory();
  }
  
  enum{
    M_TYPE = 0xf0,

    //split control states
    M_SPLITCONTROL = 0x00,
    S_OFF = 0x00,
    S_STARTING = 0x01,
    S_STOPPING = 0x02,
    
    //mid-frame states:
    // Following frame-prep, we should be in one of these states.
    M_MIDFRAME = 0x10,
    S_INACTIVE = 0x10,
    S_IDLE = 0x11,
    S_RX_PRESTART = 0x12,
    S_TX_PRESTART = 0x13,
    
    //RX intermediate states
    M_RX = 0x20,
    S_RX_START = 0x20,
    S_RX_READY = 0x21,
    S_RX_WAIT = 0x22,
    S_RX_RECEIVING = 0x23,
    S_RX_RECEIVING_FINAL = 0x24,
    S_RX_CLEANUP = 0x25,

    //TX intermediate states
    M_TX = 0x30, 
    S_TX_START = 0x30,
    S_TX_LOADING = 0x35,
    S_TX_READY = 0x31,
    S_TX_WAIT = 0x32,
    S_TX_TRANSMITTING = 0x33,
    S_TX_CLEANUP = 0x34,
    
    M_ERROR = 0xf0,
    S_ERROR_0 = 0xf0,
    S_ERROR_1 = 0xf1,
    S_ERROR_2 = 0xf2,
    S_ERROR_3 = 0xf3,
    S_ERROR_4 = 0xf4,
    S_ERROR_5 = 0xf5,
    S_ERROR_6 = 0xf6,
    S_ERROR_7 = 0xf7,
    S_ERROR_8 = 0xf8,
    S_ERROR_9 = 0xf9,
    S_ERROR_a = 0xfa,
    S_ERROR_b = 0xfb,
    S_ERROR_c = 0xfc,
    S_ERROR_d = 0xfd,
    S_ERROR_e = 0xfe,
    S_ERROR_f = 0xff,
  };
  
  //Internal state vars
  //N.B.: The recordEvent function reads this variable in the
  //interrupt context.  So, if this function is in use, it will
  //generate an atomicity warning.
  
  #ifndef CX_RECORD_EVENTS
  #define CX_RECORD_EVENTS 0
  #endif

  #if CX_RECORD_EVENTS == 1
  #warning "tracing events, mark state as norace"
  norace uint8_t state = S_OFF;
  #else
  uint8_t state = S_OFF;
  #endif

  uint8_t asyncState;
  bool pfsTaskPending = FALSE;

  //Temporary TX variables 
  message_t* tx_msg;
  uint8_t tx_len;
  bool gpResult;
  uint16_t sdFrameNum;
  error_t sdResult;
  bool sdPending;
  uint8_t sdLen;
  //used for fragmentation/precision timestamping
  uint8_t* tx_pos;
  uint8_t tx_left;
  uint32_t tx_ts;

  //only written in task context, read at capture
  norace bool tx_needsTs;
  bool tx_tsSet;

  //Temporary RX variables
  message_t rx_msg_internal;
  message_t* rx_msg = &rx_msg_internal;
  bool rdPending;
  uint8_t* rdBuffer;
  uint8_t rdCount;
  uint8_t rdResult;
  uint8_t rdS_sr;
  uint32_t rdLastRECapture;

  //re-Synch variables
  bool txCapture;
  uint32_t lastRECapture;
  uint32_t lastFECapture;
  uint16_t captureFrameNum;

  //externally-facing state vars
  uint16_t frameNum;
  uint16_t asyncFrameNum;
  uint32_t totalFrames;

  //Current radio settings
  uint8_t s_sr = SCHED_INIT_SYMBOLRATE;
  uint8_t s_channel = SCHED_INIT_CHANNEL;

  //other schedule settings
  uint32_t s_totalFrames;
  uint32_t s_totalFrames_last;
  uint8_t s_sri = 0xff;
  uint32_t s_frameLen;
  uint32_t s_fwCheckLen;
  uint32_t s_pfs_slack;
  bool s_isSynched = FALSE;

  uint16_t lastPfsStartFrame;
  uint16_t lastPfsFinishedFrame;
  uint16_t lastFwaStartFrame;
  uint16_t lastFwaFiredFrame;


  //Split control vars
  bool stopPending = FALSE;
  
  #ifndef STATE_HISTORY
  #define STATE_HISTORY 8
  #endif

  uint8_t stateTransitions[STATE_HISTORY];
  uint8_t sts = 0;
  uint8_t stl = 0;
  uint8_t pt;

  uint32_t pfsHandled;
  uint32_t fsHandled;
  //diagnostic only, don't care if it's inaccurate
  norace uint32_t fwHandled;
  //appx. time of last receiveDone event.
  uint32_t rxd;

  uint32_t rxsCount;
  uint32_t rxyCount;
  uint32_t rxdCount;

  #ifndef EVENT_HISTORY
  #define EVENT_HISTORY 32
  #endif
  uint8_t es = 0;
  uint8_t el = 0;
  uint8_t eventOrdering[EVENT_HISTORY];
  uint8_t stateOrdering[EVENT_HISTORY];
  uint8_t asyncStateOrdering[EVENT_HISTORY];


  //Radio duty cycle tracking vars
  enum{
    R_OFF = 0,
    R_SLEEP = 1,
    R_IDLE = 2, 
    R_FSTXON = 3,
    R_TX = 4,
    R_RX = 5,
    R_NUMSTATES = 6
  };

  bool captureRising = FALSE;

  #if DEBUG_RADIO_STATS == 1
  const char labels[R_NUMSTATES] = {'o', 's', 'i', 'f', 't', 'r'};
  uint8_t  curRadioState = R_OFF;
  uint32_t lastRadioStateChange;
  //because 64 bit arithmetic is no-go, keep 16-bit rollover counter
  //  as well as 32-bit time. units are ticks (e.g. 1/(6.5e6)) seconds.
  uint32_t radioStateTimes[R_NUMSTATES];
  uint16_t rollOvers[R_NUMSTATES];
  
  //update running total of time spent in each radio state.
  void radioStateChange(uint8_t newState, uint32_t changeTime){
    atomic{
      if (newState != curRadioState){
        uint32_t elapsed = changeTime-lastRadioStateChange;
        uint32_t lastTotal = radioStateTimes[curRadioState];
        radioStateTimes[curRadioState] += elapsed;
        if (lastTotal > radioStateTimes[curRadioState]){
          rollOvers[curRadioState]++;
        }
  
        curRadioState = newState;
        lastRadioStateChange = changeTime;
      }
    }
  }

  uint32_t rst[R_NUMSTATES];
  uint16_t ro[R_NUMSTATES];
  uint8_t dc_i;
  uint16_t logBatch = 0;
  bool logging = FALSE;
  uint16_t logSlot;
  
  task void logNextStat(){
    if (dc_i == 0){
      printf_RADIO_STATS("LB %u %u\r\n", logBatch, logSlot);
    }
    if (dc_i < R_NUMSTATES){
      printf_RADIO_STATS("RS %u %c %u %lu\r\n", 
        logBatch, labels[dc_i], ro[dc_i], rst[dc_i]);
      dc_i++;
      post logNextStat();
    }else{
      logging = FALSE;
    }
  }


  #else
  void radioStateChange(uint8_t newState, uint32_t changeTime){ }
  task void logDutyCycle(){ }
  #endif

  command error_t TDMAPhySchedule.logDutyCycle(uint16_t slotNum){
    #if DEBUG_RADIO_STATS == 1
    if (!logging){
      logging = TRUE;
      logSlot = slotNum;
      logBatch ++;
      dc_i = 0;
      atomic{
        int k;
        for (k=0; k < R_NUMSTATES; k++){
          rst[k] = radioStateTimes[k];
          ro[k] = rollOvers[k];
        }
      }
      post logNextStat();
      return SUCCESS;
    }else{
      return EBUSY;
    }
    #else
    return SUCCESS;
    #endif
    
  }
  
  #if CX_RECORD_EVENTS == 1
  void recordEvent(uint8_t eventId){
    atomic{
      uint8_t i = (es+el)%EVENT_HISTORY;
      stateOrdering[i] = state;
      eventOrdering[i] = eventId;
      asyncStateOrdering[i] = asyncState;
      if (el < EVENT_HISTORY){
        el++;
      }else{
        es++;
      }    
    }
  }
  #else
  void recordEvent(uint8_t eventId){}
  #endif

  task void printEvents(){
    //OK to do atomic: we only do this when we hit an error
    atomic{
      uint8_t i,j;
      printf("EVENTS:\r\n");
      for (i = 0; i < ((el < EVENT_HISTORY)? el: EVENT_HISTORY); i++){
        j = (i+es)%EVENT_HISTORY;
        printf("# e %x s %x a %x (%u)\r\n",
          eventOrdering[j], stateOrdering[j],
          asyncStateOrdering[j], j);
      }
      printf("RXS: %lu RXY: %lu RXD: %lu\r\n", rxsCount, rxyCount,
        rxdCount);
    }
  }

  task void printTransitions(){
    //OK to do atomic: we only do this when we hit an error
    atomic{
      uint8_t i;
      printf("STATE TRANSITIONS: sts: %u stl: %u\r\n", sts, stl);
      for (i = 0; i < ((stl < STATE_HISTORY)? stl: STATE_HISTORY); i++){
        printf("# %x\r\n", stateTransitions[(i+sts)%STATE_HISTORY]);
      }
    }
  }

  task void printTimers(){
    atomic{
      bool pfsaRunning = (call PrepareFrameStartAlarm.isRunning())?1:0;
      bool fsaRunning = (call FrameStartAlarm.isRunning())?1:0; 
      bool fwaRunning = (call FrameWaitAlarm.isRunning())?1:0; 
      printf("# @ %u %lu\r\n", pt, call PrepareFrameStartAlarm.getNow());
      printf("# last pfs start: %u finished: %u\r\n",
        lastPfsStartFrame, 
        lastPfsFinishedFrame);
      printf("# last fwa start: %u fired: %u\r\n",
        lastFwaStartFrame, 
        lastFwaFiredFrame);
      printf("# last RE capture: %lu last FE capture: %lu last rxd: %lu\r\n", 
        lastRECapture, lastFECapture, rxd);
      printf("# P %x %lu last %lu\r\n", 
        pfsaRunning, 
        call PrepareFrameStartAlarm.getAlarm(),
        pfsHandled);
      printf("# F %x %lu last %lu\r\n", 
        fsaRunning,
        call FrameStartAlarm.getAlarm(),
        fsHandled);
      printf("# W %x %lu last %lu\r\n", 
        fwaRunning,
        call FrameWaitAlarm.getAlarm(),
        fwHandled);
      printf("#fl: %lu fw: %lu\r\n", s_frameLen, s_fwCheckLen);
      printPfsHistory();
    }
  }

  //Utility functions
  void setState(uint8_t s){
    //once we enter error state, reject transitions
    if ((state & M_TYPE) != M_ERROR){
      if ((s & M_TYPE) == M_ERROR){
        printf("![%x->%x]\r\n", state, s);
        P2OUT |= BIT4;
        post printEvents();
        post printTransitions();
        post printTimers();
      }
      state = s;
      stateTransitions[(sts+stl)%STATE_HISTORY] = state;
      if (stl < STATE_HISTORY){
        stl++;
      }else{
        sts++;
      }
    }
  }

  task void syncState(){
    atomic {
      setState(asyncState);
    }
  }

  void setAsyncState(uint8_t s){
    atomic{
      if ((asyncState & M_TYPE) != M_ERROR){
        if ((s & M_TYPE) == M_ERROR){
          printf("!*[%x->%x]\r\n", asyncState, s);
        }
        asyncState = s;
        post syncState();
      }
    }
  }
  
  //These give us a way to report errors that arise in async context
  uint8_t asyncError;
  bool asyncErrorPending;
  task void setAsyncError(){
    atomic setState(asyncError);
  }
  void reportAsyncError(uint8_t error){
    atomic{
      if (!asyncErrorPending){
        asyncErrorPending = TRUE;
        asyncError = error;
        post setAsyncError();
      }
    }
  }

  void stopAlarms(){
    call PrepareFrameStartAlarm.stop();
    call FrameStartAlarm.stop();
    FWA_TIMING_CLEAR_PIN;
    call FrameWaitAlarm.stop();
  }

  //SplitControl operations
  command error_t SplitControl.start(){
    if (state == S_OFF){
      error_t err = call Resource.request();
      if (err == SUCCESS){
        setState(S_STARTING);
      }
      return err;
    }else{
      return EOFF;
    }
  }

  event void Resource.granted(){
    if (state == S_STARTING){
      atomic radioStateChange(R_IDLE, call TDMAPhySchedule.getNow());
      //NB: Phy impl starts the radio in IDLE
      setState(S_IDLE);
      signal SplitControl.startDone(SUCCESS);
      #if DEBUG_CONFIG == 1
        rf1a_config_t config;
        call Rf1aPhysical.readConfiguration(&config);
        call Rf1aDumpConfig.display(&config);
      #endif
    }else{
      setState(S_ERROR_0);
    }
  }
  
  command error_t SplitControl.stop(){ 
    switch(state){
      case S_OFF:
        return EALREADY;
      default:
        if (stopPending){
          return EBUSY;
        }else{
          stopPending = TRUE;
          return SUCCESS;
        }
    }
  }

  async event void Rf1aPhysical.frameStarted () { }
  async event void Rf1aPhysical.carrierSense () { }
 
  async event void Rf1aPhysical.receiveStarted (unsigned int length) { 
    atomic{
      recordEvent(6);
      rxsCount++;
      if (asyncState == S_RX_READY || asyncState == S_RX_WAIT){
        setAsyncState(S_RX_RECEIVING);
      }else{
        setAsyncState(S_ERROR_d);
      }
    }
  }
  async event void Rf1aPhysical.receiveBufferFilled (uint8_t* buffer,
                                                     unsigned int count) { }
  async event void Rf1aPhysical.clearChannel () { }
  async event void Rf1aPhysical.released () { }


  async command uint32_t TDMAPhySchedule.getNow(){
    return call FrameStartAlarm.getNow();
  }

  bool getPacket(uint16_t fn);
  
  task void pfsTask(){
    //TODO: handle splitControl.stop: if stopPending, then we need to
    //quit duty cycling, release resource, etc.
    atomic{
      //I'm seeing this task run twice in a row sometimes. how can
      //this happen?
      if (!pfsTaskPending){
        return;
      }
    }
    recordEvent(1);
//    printf_TMP("p %u -> %u m %lu: ", frameNum, frameNum+1, s_totalFrames);
    //increment frame number
    atomic{
      frameNum = (frameNum+1)%(s_totalFrames);
      asyncFrameNum = frameNum;
      totalFrames++;
    }
//    if (s_isSynched && (frameNum == s_totalFrames-1)){
//      post logDutyCycle();
//    }
    
//    printf_TMP("%u \r\n", frameNum);
    signal FrameStarted.frameStarted(frameNum);
//    printf_TMP("F %u\r\n", frameNum);
//    printf_TMP("F %u s %x ia %u\r\n", 
//      frameNum, 
//      state, 
//      signal TDMAPhySchedule.isInactive(frameNum));
    //Sleep/wake up radio as needed.
    if (state != S_INACTIVE 
        && signal TDMAPhySchedule.isInactive(frameNum)){
      if (SUCCESS == call Rf1aPhysical.sleep()){
        atomic{
          radioStateChange(R_SLEEP, call TDMAPhySchedule.getNow());
          setAsyncState(S_INACTIVE);
        }
//        printf_TMP("I@%u\r\n", frameNum);
      }else{
        setState(S_ERROR_0);
      }
      atomic pfsTaskPending = FALSE;
      //inactive, so return immediately (don't signal frameType to
      //upper layers)
      return;
    }else if (state == S_INACTIVE 
        && !signal TDMAPhySchedule.isInactive(frameNum)){
      if (SUCCESS == call Rf1aPhysical.resumeIdleMode(FALSE)){
        atomic{
          radioStateChange(R_IDLE, call TDMAPhySchedule.getNow());
          setState(S_IDLE);
        }
//        printf_TMP("A@%u\r\n", frameNum);
      }else{
        setState(S_ERROR_0);
      }
    }

    //figure out what upper layers want to do
    //set up state so that when PFS alarm fires, we can configure the
    //radio as desired.
    if (state == S_IDLE || state == S_RX_WAIT){
      switch(signal CXTDMA.frameType(frameNum)){
          case RF1A_OM_FSTXON:
            IS_TX_SET_PIN;
            if (getPacket(frameNum)){
//              printf_TMP("#TX @%u\r\n", frameNum);
              setAsyncState(S_TX_PRESTART);
            }else{
              setState(S_ERROR_0);
            }
            break;
          case RF1A_OM_RX:
            setAsyncState(S_RX_PRESTART);
            break;
          default:
            setState(S_ERROR_1);
            break;
      }
    }

    atomic pfsTaskPending = FALSE;
  } 

  void postPfs(){
    atomic {
      if (!pfsTaskPending){
        pfsTaskPending = TRUE;
        post pfsTask();
      }
    }
  }


  uint32_t origTs;

  bool getPacket(uint16_t fn){
    uint8_t* gpBufLocal;
    message_t* tx_msgLocal;
    uint8_t tx_lenLocal;
    bool gpResultLocal;
    gpResultLocal = signal CXTDMA.getPacket((message_t**)(&gpBufLocal), fn);
    tx_msgLocal = (message_t*) gpBufLocal;
    if (gpResultLocal && (tx_msgLocal != NULL)){
      tx_lenLocal = (call Rf1aPacket.metadata(tx_msgLocal))->payload_length;
      call CXPacket.incCount(tx_msgLocal);
      call CXPacket.decTTL(tx_msgLocal);
      if (call CXPacket.source(tx_msgLocal) == TOS_NODE_ID 
          && call CXPacket.count(tx_msgLocal) == 1){
        call CXPacket.setScheduleNum(tx_msgLocal, 
          signal TDMAPhySchedule.getScheduleNum());
        call CXPacket.setOriginalFrameNum(tx_msgLocal,
          fn);
        //NB timestamp obtained at SynchCapture.captured, filled in in
        //setTimestamp task, and packet fragmentation handled by
        //Rf1aFragment commands.
        //NB: this is the PRECEDING frame start: e.g. if the packet is
        //  sent in frame 1, this alarm is frame 0.
        origTs = call FrameStartAlarm.getAlarm();
        tx_needsTs = TRUE;
      }
      atomic{
        tx_msg =  tx_msgLocal;
        tx_pos = (uint8_t*) tx_msg;
        tx_len = tx_left = tx_lenLocal;
        tx_tsSet = FALSE;
        gpResult = gpResultLocal;
      }
    }
    return gpResultLocal;
  }
  
  //We should already have gathered all the info we need in pfsTask.
  //At this point, we use that information to configure the radio.
  //We'll actually do the timing-critical steps at the
  //FrameStartAlarm.fired event.
  void configureRadio();
  
  async event void PrepareFrameStartAlarm.fired(){
    PFS_TIMING_SET_PIN;
    //we see this at reset...ugh
    if (asyncState == S_OFF){
      return;
    }
    recordEvent(2);
    lastPfsStartFrame = totalFrames;
    pfsHandled = call PrepareFrameStartAlarm.getNow();
    PFS_CYCLE_TOGGLE_PIN;
//    if (call PrepareFrameStartAlarm.getNow() < 
//        call PrepareFrameStartAlarm.getAlarm()){
//      //set it again? 
//      //TODO: this has to be fixed at some point: otherwise when
//      //the 32-bit timer wraps around, it will appear to be "early"
//      call PrepareFrameStartAlarm.startAt(call PrepareFrameStartAlarm.getAlarm() - pfsHandled, 
//       pfsHandled);
//      printf("!PFS early: %lu < %lu\r\n", 
//        call PrepareFrameStartAlarm.getNow(),  
//        call PrepareFrameStartAlarm.getAlarm());
//      return;
//    }
    //cool, we got the work done in time. reschedule for next frame.
    if (!pfsTaskPending){
      //hmm. So, we set FSA relative to PFSA here. I imagine that this
      //could be problematic when we change s_pfs_slack
      //first, set up for FSA (this frame)
      call FrameStartAlarm.startAt(
        call PrepareFrameStartAlarm.getAlarm(), 
        s_pfs_slack);
      //now, set up for next PFSA (next frame)
      call PrepareFrameStartAlarm.startAt(
        call PrepareFrameStartAlarm.getAlarm(), 
        s_frameLen);
      recordPfs(0);
      ////TODO: remove debug
      atomic pt = 0;
//      post printTimers();
      configureRadio();
    }else {
      //pfs task was still pending: did not get ready in time.
      pfsTaskPending = FALSE;
      reportAsyncError(S_ERROR_2);
    }
    lastPfsFinishedFrame = totalFrames;
    PFS_TIMING_CLEAR_PIN;
  }
  
  task void loadPacket(){
    recordEvent(0xc);
    if (S_TX_LOADING == state){
      error_t error = call Rf1aPhysical.send( 
        tx_pos,
        tx_len,
        RF1A_OM_IDLE);
      if (SUCCESS != error){
        setState(S_ERROR_a);
      }
    }else{
      setState(S_ERROR_a);
    }
  }

  //actually set up the radio for the coming frame-start
  void configureRadio(){
    error_t error;
    recordEvent(3);
    switch(asyncState){
      case S_RX_PRESTART:
        //switch radio to RX, give it a buffer.
        radioStateChange(R_RX, call TDMAPhySchedule.getNow());
        error = call Rf1aPhysical.setReceiveBuffer(
          (uint8_t*)(rx_msg->header),
          TOSH_DATA_LENGTH + sizeof(message_header_t),
          TRUE,
          RF1A_OM_IDLE);
        if (error == SUCCESS){
          setAsyncState(S_RX_READY);
          call SynchCapture.captureRisingEdge();
          captureRising = TRUE;
        }
        break;

      case S_TX_PRESTART:
        radioStateChange(R_FSTXON, call TDMAPhySchedule.getNow());
        //switch radio to FSTXON.
        error = call Rf1aPhysical.startTransmission(FALSE, TRUE);
        if (error == SUCCESS){
          //NB: if this becomes split-phase, we'll set the state when we
          //get the callback.
          setAsyncState(S_TX_LOADING);
          post loadPacket();
          sdFrameNum = totalFrames;
          //get ready to capture your own SFD for re-synch and packet
          //time-stamping.
          call SynchCapture.captureRisingEdge();
          captureRising = TRUE;
        }else{
          setAsyncState(S_ERROR_0);
        }
        break;

      case S_INACTIVE:
        setAsyncState(S_INACTIVE);
        break;

      default:
        setAsyncState(S_ERROR_3);
        break;
    }
  }


  task void completeSendDone();

  async event void FrameStartAlarm.fired(){
    if (frameNum & 0x01){
      FS_CYCLE_SET_PIN;
    }else{
      FS_CYCLE_CLEAR_PIN;
    }
    {

      //OK, complete the transmission now.
      if (asyncState == S_TX_READY){
        error_t error = call DelayedSend.startSend();
        //non-deterministic completion: delay until send has started.
        fsHandled = call FrameStartAlarm.getNow();
        recordEvent(4);
        radioStateChange(R_TX, call FrameStartAlarm.getAlarm());
        //Transmission failed: stash results for send-done and post
        //task
        if (error != SUCCESS){
          if (! sdPending){
            sdPending = TRUE;
            sdResult = error;
            sdLen = 0;
            post completeSendDone();
          }else{
            //still handling last sendDone (should really never
            //happen)
            setAsyncState(S_ERROR_0);
          }
          //Try to put the radio back to idle
          error = call Rf1aPhysical.resumeIdleMode(RF1A_OM_IDLE);
          if (error != SUCCESS){
            setAsyncState(S_ERROR_0);
          }else{
            radioStateChange(R_IDLE, call TDMAPhySchedule.getNow());
          }
        }else{
          setAsyncState(S_TX_TRANSMITTING);
        }
      }else if (asyncState == S_RX_READY || asyncState == S_INACTIVE){
        recordEvent(4);
        fsHandled = call FrameStartAlarm.getNow();
        if (asyncState == S_RX_READY){
          FWA_TIMING_SET_PIN;
          lastFwaStartFrame = totalFrames;
          call FrameWaitAlarm.startAt(call FrameStartAlarm.getAlarm(), 
            s_fwCheckLen);
        ////TODO: remove debug
          atomic pt = 1;
          setAsyncState(S_RX_WAIT);
        }else if (asyncState == S_INACTIVE){
          postPfs();
        }
      }
    }
    lastFsa = call FrameStartAlarm.getAlarm();
  }


  task void reportLateCapture(){
    printf_TMP("~LATE\r\n");
  }

  async event void SynchCapture.captured(uint16_t time){
    uint32_t fst = call FrameStartAlarm.getNow();
    uint32_t lastCapture;
    recordEvent(5);

    //overflow detected: assumes that 16-bit capture time has
    //  overflowed at most once before this event runs
    if (time > (fst & 0x0000ffff)){
      fst  -= 0x00010000;
    }
    lastCapture = (fst & 0xffff0000) | time;
    if (asyncState == S_IDLE){ 
      //can sometimes get this if FWA expires just before capture
      //detected
      post reportLateCapture();
    }
    if (captureRising){
      lastRECapture = lastCapture;
      captureRising = FALSE;
      call SynchCapture.captureFallingEdge();
      switch(asyncState){
        case S_RX_WAIT:
        case S_RX_READY:
          rxyCount++;
          txCapture = FALSE;
          if (call FrameWaitAlarm.isRunning()){
            if (s_isSynched){
              //extend the alarm if we got a capture: extend to max
              //packet length
              call FrameWaitAlarm.startAt(lastRECapture,
                s_frameLen/2);
            }else{
              //TODO: if non-synched, FWA is already pushed back close
              //to boundary. We should push back both FWA and PFSA in
              //this case.
              printf_TMP("~pb\r\n");
            }
          }
  //        setAsyncState(S_RX_RECEIVING);
          break;
        case S_TX_TRANSMITTING:
          txCapture = TRUE;
          //no state change
          //if we are origin-sending, then we need to set the
          //timestamp field of the CX header and indicate that it's OK
          //to finish sending the packet.
          tx_ts = lastCapture;
          if (tx_needsTs){
            post setTimestamp();
          }
          break;
        default:
          setAsyncState(S_ERROR_4);
          break;
      } 
    }else{
      lastFECapture = lastCapture;
      //Falling edge: return to IDLE
      radioStateChange(R_IDLE, lastFECapture);

      captureRising = TRUE;
      call SynchCapture.captureRisingEdge();
    }
  }

  void resynch(){
    atomic{
      uint32_t captureFrameStart;
      call PrepareFrameStartAlarm.stop();
      //compensate for offset between FSA and transmitter SFD
      captureFrameStart = lastRECapture - fsDelays[s_sri];
      //compensate for lag between transmitter SFD and receiver SFD
      if (!txCapture){
        captureFrameStart -= sfdDelays[s_sri];
      }
      //if we're resynching, 
      // - mark ourselves synched
      // - restore timeouts
      // - restore frame number
      // - restore s_totalFrames
      if (!s_isSynched){
        s_isSynched = TRUE;
        s_frameLen = frameLens[s_sri];
        s_fwCheckLen = fwCheckLens[s_sri];
        s_totalFrames = s_totalFrames_last;
        frameNum = captureFrameNum;
      }
      call PrepareFrameStartAlarm.startAt(captureFrameStart,
        s_frameLen- s_pfs_slack);
      recordPfs(1);
      ////TODO: remove debug
      atomic pt = 2;
//      post printTimers();
    }
    signal TDMAPhySchedule.resynched(frameNum);
  }
  
  //diagnostics only, don't care if it's note 100% correct
  norace uint32_t lastFw;
  task void reportPushback(){
    printf("#pb %lu -> %lu @ %lu\r\n", lastFw, 
      call FrameWaitAlarm.getAlarm(), fwHandled);
  }

  async event void FrameWaitAlarm.fired(){
    FWA_TIMING_CLEAR_PIN;
    //see this at reset sometimes
    recordEvent(7);
    fwHandled = call FrameWaitAlarm.getNow();
    lastFwaFiredFrame = totalFrames;
    if (asyncState == S_OFF){
      return;
    }

    //NB Ideally we'd check to see if there is a pending
    //not-yet-handled synch capture interrupt (and treat this the same
    //  as S_RX_RECEIVING)
    if (asyncState == S_RX_WAIT ){
      error_t error = call Rf1aPhysical.resumeIdleMode(RF1A_OM_IDLE);
      if (error == SUCCESS){
        radioStateChange(R_IDLE, call FrameWaitAlarm.getAlarm());
        //resumeIdle alone seems to put us into a stuck state. not
        //  sure why. Radio stays in S_IDLE when we call
        //  setReceiveBuffer in pfs.f.
        //looks like this is firing when we are in the middle of a
        //receive sometimes: if this returns EBUSY, then we can assume
        //that and pretend it never happened (except that we called
        //resumeIdleMode above?
        //TODO: verify that the above information is still accurate,
        //  remove the call below if it is no longer needed
        error = call Rf1aPhysical.setReceiveBuffer(0, 0, TRUE,
          RF1A_OM_IDLE);
        if (error == SUCCESS){
          setAsyncState(S_IDLE);
          postPfs();
        }else{
          setAsyncState(S_ERROR_5);
        }
      }else{
        setAsyncState(S_ERROR_f);
      }
    } else if (asyncState == S_RX_RECEIVING){
      FWA_TIMING_SET_PIN;
      //TODO:extend the wait time for max-length packet. 
      //half-frame-length is probably too long?
      lastFw = call FrameWaitAlarm.getAlarm();
      call FrameWaitAlarm.startAt(call FrameWaitAlarm.getAlarm(),
        s_frameLen/2);
      post reportPushback();
      atomic pt = 3;
      setAsyncState(S_RX_RECEIVING_FINAL);
      return;
    } else if (asyncState == S_RX_RECEIVING_FINAL){
      //We started receiving a packet but didn't get a receiveDone.
      setAsyncState(S_ERROR_b);
      //TODO: we should force the radio to IDLE at this point and get
      //ready for next frame, assuming we've got the above timeout correct.
    } else if (asyncState == S_INACTIVE){
      //OK, we were inactive. nobigs. 
      postPfs();
    } else if (asyncState == S_RX_CLEANUP){
      //Ignore: this happens if we, for instance, postponed FWA, then
      //FWA expires while we're handling the end of the reception
    } else {
      setAsyncState(S_ERROR_6);
    }
  }
  
  task void completeReceiveDone();

  async event void Rf1aPhysical.receiveDone (uint8_t* buffer,
                                             unsigned int count,
                                             int result) {
    recordEvent(8);
    rxdCount++;
    //Is this being signalled from a non-async context somewhere? I
    //need to mark the entire thing as atomic to avoid compiler
    //warnings
    atomic{
      rxd = call FrameStartAlarm.getNow();
      FWA_TIMING_CLEAR_PIN;
      call FrameWaitAlarm.stop();
      if (asyncState == S_RX_RECEIVING 
          || asyncState == S_RX_RECEIVING_FINAL){
        //stash vars for receiveDone
        if (!rdPending){
          rdBuffer = buffer;
          rdCount = count;
          rdResult = result;
          rdS_sr = s_sr;
          rdLastRECapture = lastRECapture;
          rdPending = TRUE;
          setAsyncState(S_RX_CLEANUP);
          post completeReceiveDone();
  
          //Store packet metadata immediately
          if (result == SUCCESS){
            message_t* msg = (message_t*) buffer;
            message_metadata_t* mmd = (message_metadata_t*)(&(msg->metadata));
            rf1a_metadata_t* rf1aMD = &(mmd->rf1a);
            call Rf1aPhysicalMetadata.store(rf1aMD);
          }
        }else{
          //have not finished handling previous receive-done.
          setAsyncState(S_ERROR_0);
        }
      } else if(asyncState == S_ERROR_b){
        printf("RX gave up too early!\r\n");
        post printTimers();
      } else {
        setAsyncState(S_ERROR_7);
      }
    }
  }

  bool shouldDrop(message_t* msg){
    if (call Rf1aPacket.rssi(msg) < RSSI_THRESHOLD){
      return TRUE;
    }
    #if FWD_DROP_RATE == 0
    return FALSE;
    #else
    return ((call Random.rand32() & 0xff) < FWD_DROP_RATE);
    #endif
  }

  task void completeReceiveDone(){
    message_t* msg;
    uint8_t rdResultLocal;
    uint8_t rdCountLocal;
    uint8_t rdS_srLocal;
    uint32_t rdLastRECaptureLocal;
    recordEvent(9);
    atomic{
      msg = (message_t*) rdBuffer;
      rdResultLocal = rdResult;
      rdCountLocal = rdCount;
      rdS_srLocal = rdS_sr;
      rdLastRECaptureLocal = rdLastRECapture;
    }
    if (state == S_RX_CLEANUP){
      call Packet.setPayloadLength(msg,
        rdCountLocal-sizeof(message_header_t));
      if (call Rf1aPacket.crcPassed(msg) && rdResultLocal == SUCCESS){
        uint16_t expectedFn = call CXPacket.getOriginalFrameNum(msg) 
          + call CXPacket.count(msg) - 1;
        //filter out bad frame numbers here: only if we're
        //synched!
        if (s_isSynched && (expectedFn != frameNum)){
          printf_TMP("~R %u %u: %u + %u - 1 = %u <> %u\r\n", 
            call CXPacket.source(msg),
            call CXPacket.sn(msg),
            call CXPacket.getOriginalFrameNum(msg), 
            call CXPacket.count(msg),
            expectedFn,
            frameNum);  
        }else{ 
          call CXPacketMetadata.setSymbolRate(msg,
            rdS_srLocal);
          call CXPacketMetadata.setPhyTimestamp(msg,
            rdLastRECaptureLocal);
          call CXPacketMetadata.setFrameNum(msg,
            frameNum);
          call CXPacketMetadata.setReceivedCount(msg,
            call CXPacket.count(msg));
//          printf("RX cap %lu last fsa %lu\r\n", 
//            rdLastRECaptureLocal, lastFsa);
          if (call CXPacket.getScheduleNum(msg) == signal TDMAPhySchedule.getScheduleNum()){
            captureFrameNum = call CXPacket.getOriginalFrameNum(msg)
              + call CXPacket.count(msg) - 1;
            resynch();

            //We correct for SFD delays in resynch, assume that we
            //  see little skew/error over the course of the
            //  retransmissions that led to this reception and fill
            //  in our best estimate of when the packet's origin
            //  frame started in our time scale.
            //We get this by adding s_pfs_slack to PFSA (giving us
            //  next FSA), then subtracting off one frame len for
            //  each hop it's traveled (e.g. subtract 1: this gives us
            //  start of the frame in which we received it).
            call CXPacketMetadata.setOriginalFrameStartEstimate(msg,
              call PrepareFrameStartAlarm.getAlarm()+s_pfs_slack -
              s_frameLen*(call CXPacketMetadata.getReceivedCount(msg)));
          }else{
            call CXPacketMetadata.setOriginalFrameStartEstimate(msg, 0);
          }
  //        printf_TMP("#RX %u @ %u\r\n", 
  //          call CXPacket.sn(msg),
  //          frameNum);
          printf_LINK_RXTX("RD %u %u %u %u %u\r\n",
            call CXPacket.getNetworkProtocol(msg),
            call CXPacket.source(msg),
            call CXPacket.sn(msg),
            call CXPacket.count(msg),
            frameNum);
          if (shouldDrop(msg)){
            printf_LINK_RXTX("DROP %u %u %u %u %u %d %d\r\n",
              call CXPacket.getNetworkProtocol(msg),
              call CXPacket.source(msg),
              call CXPacket.sn(msg),
              call CXPacket.count(msg),
              frameNum,
              call Rf1aPacket.rssi(msg),
              RSSI_THRESHOLD);
          } else {
            rx_msg = signal CXTDMA.receive(msg,
              rdCountLocal - sizeof(rf1a_ieee154_t),
              frameNum, rdLastRECaptureLocal);
          }
        }
      }
      setAsyncState(S_IDLE);
      postPfs();
    }else{
      setState(S_ERROR_c);
    }
    atomic rdPending = FALSE;

  }

  async event void Rf1aPhysical.sendDone (int result) { 
    recordEvent(10);
    //OK, so we have to put this in an atomic block b/c the phy layer
    //actually signals this from the task context (even though it's
    //marked async).
    atomic{
      if (asyncState == S_TX_TRANSMITTING){
        if (sdPending ){
          setAsyncState(S_ERROR_9);
        }else {
          sdPending = TRUE;
          sdResult = result;
          sdLen = tx_len;
          post completeSendDone();
        }
      }
    }
  }

  task void completeSendDone(){
    message_t* sdMsgLocal;
    uint8_t sdLenLocal;
    error_t sdResultLocal;
    uint32_t sdRECaptureLocal;
    IS_TX_CLEAR_PIN;
    recordEvent(11);
    atomic{
      sdMsgLocal = tx_msg;
      sdLenLocal = sdLen;
      sdResultLocal = sdResult;
      sdRECaptureLocal = lastRECapture;
    }
    if ( call CXPacket.source(sdMsgLocal) == TOS_NODE_ID 
        && call CXPacket.count(sdMsgLocal) == 1){
      call CXPacketMetadata.setPhyTimestamp(sdMsgLocal,
        sdRECaptureLocal);
    }
    captureFrameNum = frameNum;
    resynch();

    printf_LINK_RXTX("SD %u %u %u %u %u\r\n",
      call CXPacket.getNetworkProtocol(sdMsgLocal),
      call CXPacket.source(sdMsgLocal),
      call CXPacket.sn(sdMsgLocal),
      call CXPacket.count(sdMsgLocal),
      frameNum);
    
    if (SUCCESS == signal CXTDMA.sendDone(sdMsgLocal, sdLenLocal, frameNum,
        sdResultLocal)){
      setAsyncState(S_IDLE);
      postPfs();
    }else{
      setAsyncState(S_ERROR_e);
    }
    atomic sdPending = FALSE;
  }

  error_t checkSetSchedule(){
    switch(state){
      case S_IDLE:
      case S_INACTIVE:
      case S_RX_PRESTART:
      case S_TX_PRESTART:
        if (call Rf1aStatus.get() == RF1A_S_IDLE 
            || call Rf1aStatus.get() == RF1A_S_CALIBRATE){
          return SUCCESS;
        } else{
          return ERETRY;
        }
      case S_OFF:
        return EOFF;
      default:
        return ERETRY;
    }
  }
  
//  command error_t TDMAPhySchedule.nudgeSchedule(int32_t nudge){
//    if (call FrameStartAlarm.isRunning()){
//      uint32_t curAlarm = call FrameStartAlarm.getAlarm();
//      call FrameStartAlarm.startAt(curAlarm - s_frameLen, 
//        s_frameLen + nudge);
//    }
//    if (call PrepareFrameStartAlarm.isRunning()){
//      uint32_t curAlarm = call PrepareFrameStartAlarm.getAlarm();
//      call PrepareFrameStartAlarm.startAt(curAlarm - s_frameLen,
//        s_frameLen + nudge);
//    }
//  }
  command error_t TDMAPhySchedule.adjustFrameStart(uint32_t startAt,
      uint16_t atFrameNum){
    //we assume that atFrameNum is in the past.
    //we need to advance atFrameNum forwarder until it hits the
    //current frame number (since PFSA is matched up with a packet
    //that was transmitted during that frame).

    //TODO: this shouldn't be in a loop! if atFrameNum < frameNum,
    //      just get the diff and multiply it out. If atFrameNum >
    //      frameNum, do it in the reverse direction.
    while (atFrameNum != frameNum){
      startAt += s_frameLen;
      atFrameNum = (atFrameNum+1)%s_totalFrames;
    }

    if (call FrameStartAlarm.isRunning()){
      call FrameStartAlarm.startAt(startAt - s_frameLen,
        s_frameLen);
      printf("~live FSA\r\n");
    }
    if (call PrepareFrameStartAlarm.isRunning()){
      call PrepareFrameStartAlarm.startAt(startAt - s_frameLen - s_pfs_slack,
        s_frameLen);
      recordPfs(2);
    }
    //TODO: I would like to make sure that we're not setting up a case
    //  where it will fire immediately, but I'm not sure how at the
    //  moment: this gets messy when the timer wraps around.
    return SUCCESS;
  }

  command error_t TDMAPhySchedule.setSchedule(uint32_t startAt,
      uint16_t atFrameNum, uint16_t totalFramesSched, uint8_t symbolRate, 
      uint8_t channel, bool isSynched, bool skewCorrected){
    error_t err;
    atomic{
      err = checkSetSchedule();
      if (err == SUCCESS){
        uint32_t pfsStartAt;
        uint8_t last_sr = s_sr;
        uint8_t last_channel = s_channel;
        uint32_t t0;
        uint32_t dt;
        s_totalFrames = totalFramesSched;
        //need to hang onto this for the case where we can do a fast
        //resynch.
        if (isSynched){
          s_totalFrames_last = s_totalFrames;
        }
        s_sr = symbolRate;
        s_sri = srIndex(s_sr);
        s_frameLen = frameLens[s_sri];

        //double guard times if no skew correction available
        if ( skewCorrected){
          s_pfs_slack = PFS_SLACK;
          s_fwCheckLen = fwCheckLens[s_sri];
        }else{
          s_pfs_slack = 2*PFS_SLACK;
          s_fwCheckLen = 2*fwCheckLens[s_sri];
        }
  
        stopAlarms();
        setState(S_IDLE);
        call SynchCapture.disable();
////if we passed the checks above,  the radio *should* already be idle.
//        err = call Rf1aPhysical.resumeIdleMode();
//        if (err == SUCCESS){
//          err = call
//          Rf1aPhysical.setReceiveBuffer((uint8_t*)rx_msg->header,
//            TOSH_DATA_LENGTH+sizeof(message_header_t), 
//            RF1A_OM_IDLE);
//          if (err == SUCCESS){
//          }else{
//            setState(S_ERROR_8);
//          }
//        }else{
//          setState(S_ERROR_9);
//        }
        if (err == SUCCESS){
          //not synched: set the frame wait timeout to almost-frame len
          if (!isSynched){
            s_frameLen *= 20;
            s_fwCheckLen = s_frameLen-2*s_pfs_slack;
//            printf_TMP("Original FL %lu Using FL %lu FW %lu\r\n",
//              frameLens[s_sri], s_frameLen, s_fwCheckLen);
          }
          

          //while target frameStart is in the past
          // - add 1 to target frameNum, add framelen to target frameStart
          //TODO: fix issue with s_pfs_slack causing numbers to wrap
          pfsStartAt = startAt - s_pfs_slack ;
          while (pfsStartAt < call PrepareFrameStartAlarm.getNow()){
            pfsStartAt += s_frameLen;
            atFrameNum = (atFrameNum + 1)%(s_totalFrames);
          }
    
          //now that target is in the future: 
          //  - set frameNum to target framenum - 1 (so that pfs counts to
          //    correct frame num when it fires).
          if (atFrameNum == 0){
            frameNum = s_totalFrames-1;
          }else{
            frameNum = atFrameNum - 1;
          }
   
          //  - set t0 and dt to arbitrary values s.t t0 + dt =
          //    target frame start AND t0 is in the past
          t0 = call PrepareFrameStartAlarm.getNow();
          dt = pfsStartAt - t0;
          call PrepareFrameStartAlarm.startAt(t0,
            dt);
          recordPfs(3);
//          printf_TMP("t0 %lu dt %lu a %lu\r\n", 
//            t0, dt, 
//            call PrepareFrameStartAlarm.getAlarm());

          ////TODO: remove debug
          atomic pt = 4;
    //      post printTimers();

          s_isSynched = isSynched;
    
          //If channel or symbol rate changes, need to reconfigure
          //  radio.
          if (s_sr != last_sr || s_channel != last_channel){
            call Rf1aPhysical.reconfigure();
          }
          //setSchedule may update frame number and adjust timers. we
          //  only signal CXTDMA.frameType from pfsTask if we're
          //  in IDLE or RX_WAIT. So, SS updates frameNum/next alarm
          //  to be consistent, upper layers *may* see discontinuity in
          //  frame numbers. 
          //However,this seems unlikely to cause a problem. For a
          //  discontinuity to show up that actually matters (i.e.
          //  interferes with a pending transmission/wait-for-clear at
          //  the network layer), the network layer would have to
          //  think that we are in synch while the link layer has
          //  drifted by enough to cause a jump (because it's
          //  really drifted past a frame boundary (which should 
          //  be detected as a synch-loss)). Assuming that the logic
          //  for setting the next-frame boundary and next-frame
          //  number is correct, it should be safe to delay this
          //  arbitrarily long (though it will work best if it's
          //  handled just after the forwarding has concluded).
          postPfs();      
        }
      }else{
//        printf_TMP("CheckSchedule: %x %x %s\r\n", 
//          state, call Rf1aStatus.get(), decodeError(err));
      }
    }
//    post printPfsHistoryTask();
//    printf_TMP("Using s_pfs_slack: %lu s_fwCheckLen: %lu\r\n",
//      s_pfs_slack, s_fwCheckLen);
    return err;
  }

  command uint32_t TDMAPhySchedule.getFrameLen(){
    return s_frameLen;
  }

  async command const rf1a_config_t* Rf1aConfigure.getConfiguration(){
    printf_SCHED_SR("Get configuration: %u\r\n", s_sr);
    return call SubRf1aConfigure.getConfiguration[s_sr]();
  }
  async command const rf1a_fscal_t* Rf1aConfigure.getFSCAL(uint8_t channel){
    return call SubRf1aConfigure.getFSCAL[s_sr](channel);
  }
  async command void Rf1aConfigure.setFSCAL(uint8_t channel,
      rf1a_fscal_t fscal){
    call SubRf1aConfigure.setFSCAL[s_sr](channel, fscal);
  }

  event void DelayedSend.sendReady(){
    recordEvent(0xd);
    if (state == S_TX_LOADING){
      setAsyncState(S_TX_READY);
    }else{
      setState(S_ERROR_a);
    }
  }
  

  task void setTimestamp(){
    uint32_t ts;
    atomic{
      tx_needsTs = FALSE;
      ts = tx_ts;
    }

    //This value corresponds to the "ideal" framestart alarm that
    //  triggered the transmission (sfd - fsDelay). In practice, the
    //  frame start alarm may be different from this (e.g. due to
    //  interrupt-handling jitter).
    // - if we were really hardcore, we could use a SW capture at the
    //   right before STX to get this jitter down basically to 0
    //   (asynchrony between XT2 and MCLK DCO, somewhere around 1/16M
    //   seconds)
    call CXPacket.setTimestamp(tx_msg, ts - fsDelays[s_sri]);
    tx_tsSet = TRUE;
  }
  
  async command unsigned int Rf1aTransmitFragment.transmitReadyCount(unsigned int count){
    unsigned int available;
    //pause at the start of the timestamp field if we haven't figured it out
    //yet.
    if (tx_tsSet){
      available = tx_left;
    }else{
      available = call CXPacket.getTimestampAddr(tx_msg) - tx_pos;
    }
    return (available > count)? count : available;
  }

  async command const uint8_t* Rf1aTransmitFragment.transmitData(unsigned int count){
    unsigned int available = call Rf1aTransmitFragment.transmitReadyCount(count);
    const uint8_t* ret= tx_pos;
    tx_left -= available;
    tx_pos += available;
    return ret;
  }

  async command void Rf1aConfigure.preConfigure (){ }
  async command void Rf1aConfigure.postConfigure (){ }
  async command void Rf1aConfigure.preUnconfigure (){}
  async command void Rf1aConfigure.postUnconfigure (){}

  default async command void SubRf1aConfigure.preConfigure [uint8_t client](){ }
  default async command void SubRf1aConfigure.postConfigure [uint8_t client](){}
  default async command void SubRf1aConfigure.preUnconfigure [uint8_t client](){}
  default async command void SubRf1aConfigure.postUnconfigure [uint8_t client](){}

  default async command const rf1a_fscal_t* SubRf1aConfigure.getFSCAL[uint8_t client](uint8_t channel){
    return NULL;
  }
  default async command void SubRf1aConfigure.setFSCAL[uint8_t client](uint8_t channel, 
    rf1a_fscal_t fscal){}

  default async command const rf1a_config_t* SubRf1aConfigure.getConfiguration[uint8_t client] ()
  {
    printf("CXTDMAPhysicalP: Unknown sr requested: %u\r\n", client);
    return call SubRf1aConfigure.getConfiguration[1]();
  }
  }
