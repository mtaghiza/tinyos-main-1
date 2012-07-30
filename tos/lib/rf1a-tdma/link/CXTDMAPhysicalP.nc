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
  uint8_t state = S_OFF;
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
  uint32_t lastCapture;

  //externally-facing state vars
  uint16_t frameNum;
  uint16_t asyncFrameNum;

  //Current radio settings
  uint8_t s_sr = SCHED_INIT_SYMBOLRATE;
  uint8_t s_channel = TEST_CHANNEL;

  //other schedule settings
  uint32_t s_totalFrames;
  uint8_t s_sri = 0xff;
  uint32_t s_frameLen;
  uint32_t s_fwCheckLen;
  bool s_isSynched = FALSE;


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
  uint32_t fwHandled;
  //appx. time of last receiveDone event.
  uint32_t rxd;

  #ifndef EVENT_HISTORY
  #define EVENT_HISTORY 32
  #endif
  uint8_t es = 0;
  uint8_t el = 0;
  uint8_t eventOrdering[EVENT_HISTORY];
  uint8_t stateOrdering[EVENT_HISTORY];
  uint8_t asyncStateOrdering[EVENT_HISTORY];
  
  //This should be removed when debugging is done!
  void recordEventX(uint8_t eventId){}
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
      printf("# @ %u %lu\r\n", pt, call PrepareFrameStartAlarm.getNow());
      printf("# last capture: %lu last rxd: %lu\r\n", lastCapture, rxd);
      printf("# P %x %lu last %lu\r\n", 
        (call PrepareFrameStartAlarm.isRunning())?1:0, 
        call PrepareFrameStartAlarm.getAlarm(),
        pfsHandled);
      printf("# F %x %lu last %lu\r\n", 
        (call FrameStartAlarm.isRunning())?1:0, 
        call FrameStartAlarm.getAlarm(),
        fsHandled);
      printf("# W %x %lu last %lu\r\n", 
        (call FrameWaitAlarm.isRunning())?1:0, 
        call FrameWaitAlarm.getAlarm(),
        fwHandled);
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
      //NB: Phy impl starts the radio in IDLE
      setState(S_IDLE);
      signal SplitControl.startDone(SUCCESS);
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


  async event bool Rf1aPhysical.getPacket(uint8_t** buffer, 
      uint8_t* len){
    *buffer = (uint8_t*)tx_msg;
    *len = tx_len;
    return gpResult;
  }

  async event uint8_t Rf1aPhysical.getChannelToUse(){
    return s_channel;
  }
  async event void Rf1aPhysical.frameStarted () { }
  async event void Rf1aPhysical.carrierSense () { }
 
  async event void Rf1aPhysical.receiveStarted (unsigned int length) { 
    atomic{
      recordEvent(6);
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

  async event bool Rf1aPhysical.idleModeRx () { return FALSE; }

  async command uint32_t TDMAPhySchedule.getNow(){
    return call FrameStartAlarm.getNow();
  }

  bool getPacket(uint16_t fn);

  task void pfsTask(){
    atomic{
      //I'm seeing this task run twice in a row sometimes. how can
      //this happen?
      if (!pfsTaskPending){
        return;
      }
    }
    recordEvent(1);
    //increment frame number
    atomic{
      frameNum = (frameNum+1)%(s_totalFrames);
      asyncFrameNum = frameNum;
    }
    signal FrameStarted.frameStarted(frameNum);
    
    //Sleep/wake up radio as needed.
    if (state != S_INACTIVE 
        && signal TDMAPhySchedule.isInactive(frameNum)){
      if (SUCCESS == call Rf1aPhysical.sleep()){
        setAsyncState(S_INACTIVE);
      }else{
        setState(S_ERROR_0);
      }
    }else if (state == S_INACTIVE 
        && !signal TDMAPhySchedule.isInactive(frameNum)){
      if (SUCCESS == call Rf1aPhysical.resumeIdleMode()){
        setAsyncState(S_IDLE);
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



  bool getPacket(uint16_t fn){
    uint8_t* gpBufLocal;
    message_t* tx_msgLocal;
    uint8_t tx_lenLocal;
    bool gpResultLocal;
    gpResultLocal = signal CXTDMA.getPacket((message_t**)(&gpBufLocal), fn);
    tx_msgLocal = (message_t*) gpBufLocal;
    if (gpResultLocal && tx_msgLocal != NULL){
      tx_lenLocal = (call Rf1aPacket.metadata(tx_msgLocal))->payload_length;
      call CXPacket.incCount(tx_msgLocal);
      if (call CXPacket.source(tx_msgLocal) == TOS_NODE_ID 
          && call CXPacket.count(tx_msgLocal) == 1){
        call CXPacket.setScheduleNum(tx_msgLocal, 
          signal TDMAPhySchedule.getScheduleNum());
        call CXPacket.setOriginalFrameNum(tx_msgLocal,
          fn);
      }
      atomic{
        tx_msg = tx_msgLocal;
        tx_len = tx_lenLocal;
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
    recordEvent(2);
    pfsHandled = call PrepareFrameStartAlarm.getNow();
    PFS_CYCLE_TOGGLE_PIN;
    if (call PrepareFrameStartAlarm.getNow() < 
        call PrepareFrameStartAlarm.getAlarm()){
      //set it again? 
      //TODO: this has to be fixed at some point: otherwise when
      //the 32-bit timer wraps around, it will appear to be "early"
      call PrepareFrameStartAlarm.startAt(call PrepareFrameStartAlarm.getAlarm() - pfsHandled, 
       pfsHandled);
      printf("!PFS early: %lu < %lu\r\n", 
        call PrepareFrameStartAlarm.getNow(),  
        call PrepareFrameStartAlarm.getAlarm());
      return;
    }
    //cool, we got the work done in time. reschedule for next frame.
    if (!pfsTaskPending){
      //first, set up for FSA (this frame)
      call FrameStartAlarm.startAt(
        call PrepareFrameStartAlarm.getAlarm(), 
        PFS_SLACK);
      //now, set up for next PFSA (next frame)
      call PrepareFrameStartAlarm.startAt(
        call PrepareFrameStartAlarm.getAlarm(), 
        s_frameLen);
      ////TODO: remove debug
      atomic pt = 0;
//      post printTimers();
      configureRadio();
    }else {
      //pfs task was still pending: did not get ready in time.
      pfsTaskPending = FALSE;
      reportAsyncError(S_ERROR_2);
    }
  }
  
  //actually set up the radio for the coming frame-start
  void configureRadio(){
    error_t error;
    recordEvent(3);
    switch(asyncState){
      case S_RX_PRESTART:
        //switch radio to RX, give it a buffer.
        error = call Rf1aPhysical.setReceiveBuffer(
          (uint8_t*)(rx_msg->header),
          TOSH_DATA_LENGTH + sizeof(message_header_t),
          RF1A_OM_IDLE);
        if (error == SUCCESS){
          setAsyncState(S_RX_READY);
          call SynchCapture.captureRisingEdge();
        }
        break;

      case S_TX_PRESTART:
        //switch radio to FSTXON.
        error = call Rf1aPhysical.startSend(FALSE, RF1A_OM_IDLE);
        if (error == SUCCESS){
          //NB: if this becomes split-phase, we'll set the state when we
          //get the callback.
          setAsyncState(S_TX_READY);
          sdFrameNum = asyncFrameNum;
          //get ready to capture your own SFD for re-synch.
          call SynchCapture.captureRisingEdge();
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
    recordEvent(4);
    //TODO: this is probably not safe: non-deterministic completion
    //time!
    fsHandled = call FrameStartAlarm.getNow();
    if (fsHandled < 
        call FrameStartAlarm.getAlarm()){
      printf("!FS early: %lu < %lu\r\n", 
        fsHandled,  
        call FrameStartAlarm.getAlarm());
      setAsyncState(S_ERROR_a);
      return;
    }else{
      //OK, complete the transmission now.
      if (asyncState == S_TX_READY){
        error_t error = call Rf1aPhysical.completeSend();
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
          error = call Rf1aPhysical.resumeIdleMode();
          if (error != SUCCESS){
            setAsyncState(S_ERROR_0);
          }
        }else{
          setAsyncState(S_TX_TRANSMITTING);
        }
      }else if (asyncState == S_RX_READY || asyncState == S_INACTIVE){
        call FrameWaitAlarm.startAt(call FrameStartAlarm.getAlarm(), 
          s_fwCheckLen);
      ////TODO: remove debug
        atomic pt = 1;
//        post printTimers();
        if (asyncState == S_RX_READY){
          setAsyncState(S_RX_WAIT);
        }
      }
    }
  }
  

  async event void SynchCapture.captured(uint16_t time){
    uint32_t fst = call FrameStartAlarm.getNow();
    recordEvent(5);

    //overflow detected: assumes that 16-bit capture time has
    //  overflowed at most once before this event runs
    if (time > (fst & 0x0000ffff)){
      fst  -= 0x00010000;
    }
    lastCapture = (fst & 0xffff0000) | time;
    call SynchCapture.disable();
    switch(asyncState){
      case S_RX_WAIT:
      case S_RX_READY:
        txCapture = FALSE;
//        setAsyncState(S_RX_RECEIVING);
        break;
      case S_TX_TRANSMITTING:
        txCapture = TRUE;
        //no state change
        break;
      default:
        setAsyncState(S_ERROR_4);
        break;
    }
  }

  void resynch(){
    atomic{
      uint32_t captureFrameStart;
      call PrepareFrameStartAlarm.stop();
      captureFrameStart = lastCapture - fsDelays[s_sri];
      if (!txCapture){
        captureFrameStart -= sfdDelays[s_sri];
      }
      call PrepareFrameStartAlarm.startAt(captureFrameStart,
        s_frameLen- PFS_SLACK);
      ////TODO: remove debug
      atomic pt = 2;
//      post printTimers();
    }
    signal TDMAPhySchedule.resynched(frameNum);
  }
  
  uint32_t lastFw;
  task void reportPushback(){
    printf("#pb %lu -> %lu @ %lu\r\n", lastFw, 
      call FrameWaitAlarm.getAlarm(), fwHandled);
  }

  async event void FrameWaitAlarm.fired(){
    recordEvent(7);
    fwHandled = call FrameWaitAlarm.getNow();
    if (asyncState == S_RX_WAIT){
      error_t error = call Rf1aPhysical.resumeIdleMode();
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
          setAsyncState(S_IDLE);
          postPfs();
        }else{
          setAsyncState(S_ERROR_5);
        }
      }
    } else if (asyncState == S_RX_RECEIVING){
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
      //TODO: this comes up prettty often. correct?
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
    //Is this being signalled from a non-async context somewhere? I
    //need to mark the entire thing as atomic to avoid compiler
    //warnings
    atomic{
      rxd = call FrameStartAlarm.getNow();
      call FrameWaitAlarm.stop();
      if (asyncState == S_RX_RECEIVING 
          || asyncState == S_RX_RECEIVING_FINAL){
        //stash vars for receiveDone
        if (!rdPending){
          rdBuffer = buffer;
          rdCount = count;
          rdResult = result;
          rdS_sr = s_sr;
          rdLastRECapture = lastCapture;
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
      if (SUCCESS == rdResultLocal){
        call Packet.setPayloadLength(msg,
          rdCountLocal-sizeof(message_header_t));
        if (call Rf1aPacket.crcPassed(msg)){
          call CXPacketMetadata.setSymbolRate(msg,
            rdS_srLocal);
          call CXPacketMetadata.setPhyTimestamp(msg,
            rdLastRECaptureLocal);
          call CXPacketMetadata.setFrameNum(msg,
            frameNum);
          call CXPacketMetadata.setReceivedCount(msg,
            call CXPacket.count(msg));
          if (call CXPacket.getScheduleNum(msg) == signal TDMAPhySchedule.getScheduleNum()){
            resynch();
          }
  //        printf_TMP("#RX %u @ %u\r\n", 
  //          call CXPacket.sn(msg),
  //          frameNum);
          rx_msg = signal CXTDMA.receive(msg,
            rdCountLocal - sizeof(rf1a_ieee154_t),
            frameNum, rdLastRECaptureLocal);
        }
        setAsyncState(S_IDLE);
        postPfs();
      }
    }else{
      setState(S_ERROR_c);
    }
    atomic rdPending = FALSE;

  }

  async event void Rf1aPhysical.sendDone (uint8_t* buffer, 
      uint8_t len, int result) { 
    recordEvent(10);
    if (asyncState == S_TX_TRANSMITTING){
      if (sdPending || (message_t*)buffer != tx_msg){
        setAsyncState(S_ERROR_9);
      }else {
        sdPending = TRUE;
        sdResult = result;
        sdLen = len;
        post completeSendDone();
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
      sdRECaptureLocal = lastCapture;
    }
    if ( call CXPacket.source(sdMsgLocal) == TOS_NODE_ID 
        && call CXPacket.count(sdMsgLocal) == 1){
      call CXPacketMetadata.setPhyTimestamp(sdMsgLocal,
        sdRECaptureLocal);
    }
    resynch();
    signal CXTDMA.sendDone(sdMsgLocal, sdLenLocal, frameNum,
      sdResultLocal);

    setAsyncState(S_IDLE);
    postPfs();
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

  command error_t TDMAPhySchedule.setSchedule(uint32_t startAt,
      uint16_t atFrameNum, uint16_t totalFrames, uint8_t symbolRate, 
      uint8_t channel, bool isSynched){
    error_t err;
    atomic{
      err = checkSetSchedule();
      if (err == SUCCESS){
        uint32_t pfsStartAt;
        uint8_t last_sr = s_sr;
        uint8_t last_channel = s_channel;
        uint32_t t0;
        uint32_t dt;
        s_totalFrames = totalFrames;
        s_sr = symbolRate;
        s_sri = srIndex(s_sr);
        s_frameLen = frameLens[s_sri];
        s_fwCheckLen = fwCheckLens[s_sri];
  
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
            s_fwCheckLen = s_frameLen-2*PFS_SLACK;
//            printf_TMP("Original FL %lu Using FL %lu FW %lu\r\n",
//              frameLens[s_sri], s_frameLen, s_fwCheckLen);
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
    
          //  - set t0 and dt to arbitrary values s.t t0 + dt =
          //    target frame start AND t0 is in the past
          t0 = call PrepareFrameStartAlarm.getNow();
          dt = pfsStartAt - t0;
          call PrepareFrameStartAlarm.startAt(t0,
            dt);

          ////TODO: remove debug
          atomic pt = 4;
    //      post printTimers();

          s_isSynched = isSynched;
    
          //If channel or symbol rate changes, need to reconfigure
          //  radio.
          if (s_sr != last_sr || s_channel != last_channel){
            call Rf1aPhysical.reconfigure();
          }
          //TODO: careful about duplicate posting: if we were in
          // *_PRESTART, then we can adjust timers but SHOULD NOT re-post
          // the task.
          postPfs();      
        }
      }else{
//        printf_TMP("CheckSchedule: %x %x %s\r\n", 
//          state, call Rf1aStatus.get(), decodeError(err));
      }
    }
    return err;
  }

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
  }}
