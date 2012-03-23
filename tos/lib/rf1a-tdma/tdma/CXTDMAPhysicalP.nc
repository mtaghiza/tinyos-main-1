/**
 * Implementation of protocol-independent TDMA.
 *  - Duty cycling
 *  - request data at frame start
 */
 #include "CXTDMA.h"
 #include "CXTDMADebug.h"

module CXTDMAPhysicalP {
  provides interface SplitControl;
  provides interface CXTDMA;
  provides interface TDMAPhySchedule;
  provides interface FrameStarted;

  uses interface HplMsp430Rf1aIf;
  uses interface Resource;
  uses interface Rf1aPhysical;
  uses interface Rf1aPhysicalMetadata;
  uses interface Rf1aStatus;

  uses interface Rf1aPacket;
  uses interface CXPacket;
  uses interface CXPacketMetadata;

  uses interface Alarm<TMicro, uint32_t> as PrepareFrameStartAlarm;
  uses interface Alarm<TMicro, uint32_t> as FrameStartAlarm;
  uses interface Alarm<TMicro, uint32_t> as FrameWaitAlarm;
  uses interface GpioCapture as SynchCapture;
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

  uint8_t state = S_OFF;

  uint8_t captureMode = MSP430TIMER_CM_NONE;

  uint16_t frameNum;
  uint32_t s_frameStart;
  uint32_t s_frameLen;
  uint16_t s_activeFrames;
  uint16_t s_inactiveFrames;
  uint32_t s_fwCheckLen;

  uint32_t lastRECapture;
  uint32_t lastFECapture;
  uint32_t lastFsa;

  bool scStopPending;
  error_t scStopError;

  message_t rx_msg_internal;
  message_t* rx_msg = &rx_msg_internal;
  uint8_t rx_count; 

  message_t* tx_msg;

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

  void completeCleanup();
  task void signalStopDone();

  void printStatus(){
    printf("* Core: %s\r\n", decodeStatus());
    printf("--------\r\n");
  }

  task void printStatusTask(){
    printStatus();
  }

  void stopTimers(){
    call PrepareFrameStartAlarm.stop();
    call FrameStartAlarm.stop();
    call FrameWaitAlarm.stop();
    call SynchCapture.disable();
  }

  bool checkState(uint8_t s){ atomic return (state == s); }
  void setState(uint8_t s){
    atomic {
      if (state == s){
        return;
      }
      #ifdef DEBUG_CX_TDMA_P_STATE
      printf("[%x->%x]\r\n", state, s);
      #endif
      #ifdef DEBUG_CX_TDMA_P_STATE_ERROR
      if (ERROR_MASK == (s & ERROR_MASK)){
        P2OUT |= BIT4;
        stopTimers();
        printf("[%x->%x]\r\n", state, s);
      }
      #endif
      state = s;
    }
  }

  bool inError(){
    atomic return (ERROR_MASK & state);
  }


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
      printStatus();
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
//      printStatus();
      signal SplitControl.startDone(SUCCESS);
    }
  }

  /**
   *  S_IDLE: in the part of a frame where no data is expected.
   *    frameNum > activeFrames / call resource.release()
   *      -> S_INACTIVE
   *    frameNum = activeFrames + inactiveFrames - 1 / call
   *        Resource.request()
   *      -> S_STARTING
   *    PFS.fired + !isTX / setReceiveBuffer + startReception + set
   *      next PrepareFrameStartAlarm + start capture
   *      -> S_RX_READY
   *    PFS.fired + isTX  / startTransmit(FSTXON) -> S_TX_READY
   */
  async event void PrepareFrameStartAlarm.fired(){
    error_t error;
    if(call PrepareFrameStartAlarm.getNow() < call PrepareFrameStartAlarm.getAlarm()){
      printf_PFS_FREAKOUT("PFS EARLY");
      call PrepareFrameStartAlarm.startAt(
        call PrepareFrameStartAlarm.getAlarm() - s_frameLen, 
        s_frameLen);
      return;
    }
    PFS_CYCLE_TOGGLE_PIN;
    PFS_SET_PIN;
    frameNum = (frameNum + 1)%(s_activeFrames + s_inactiveFrames);
    printf_PFS("*%u %lu (%lu)\r\n", frameNum, 
      call PrepareFrameStartAlarm.getNow(), 
      call PrepareFrameStartAlarm.getAlarm());
    if (scStopPending){
      scStopError = call Resource.release();
      if (SUCCESS == scStopError){
        stopTimers();
        scStopPending = FALSE;
        setState(S_STOPPING);
      } else{
        setState(S_ERROR_f);
      }
      post signalStopDone();
      PFS_CLEAR_PIN;
      return;
    }
    signal FrameStarted.frameStarted(frameNum);
    //0.5uS
    PFS_TOGGLE_PIN;
    if (s_inactiveFrames > 0){
      //if there are n active frames, then frameNum n-1 is the last to
      //have data in it. so, we go to sleep at this point.
      if (frameNum == s_activeFrames){
//        printf("sleep\r\n");
        if (SUCCESS == call Rf1aPhysical.sleep()){
          call FrameStartAlarm.stop();
          call FrameWaitAlarm.stop();
          //TODO: post task to indicate that we are done with the
          //active phase?
//          printf_PFS_FREAKOUT("Inactive: %u\r\n", frameNum);
          setState(S_INACTIVE);
        } else {
          setState(S_ERROR_1);
        }

      //wake up radio when we come around the bend.
      } else if (frameNum == 0 ){
//        printf("wakeup\r\n");
        if (SUCCESS == call Rf1aPhysical.resumeIdleMode()){
//          printf("fs@ %lu + %lu\r\n", call PrepareFrameStartAlarm.getAlarm(), PFS_SLACK);
          call FrameStartAlarm.startAt(
            call PrepareFrameStartAlarm.getAlarm(), 
            PFS_SLACK);
          setState(S_IDLE);
        } else {
          setState(S_ERROR_2);
        }
      } 
    }
//    printf("pfs %x %s\r\n", state, decodeStatus());
    //Idle, or we are in an extra long frame-wait (e.g. trying to
    //  synch), or we started receiving, but gave up.
    if (checkState(S_IDLE) || checkState(S_RX_READY) 
        || checkState(S_TX_READY) || checkState(S_RECEIVING)){
//      printf("PFS %s\r\n", decodeStatus());
      //7.75 uS
      PFS_TOGGLE_PIN;
      switch(signal CXTDMA.frameType(frameNum)){
        case RF1A_OM_FSTXON:
          //0.75 uS
          PFS_TOGGLE_PIN;
//          printf("TX from %s\r\n", decodeStatus());
          error = call Rf1aPhysical.startSend(FALSE, RF1A_OM_IDLE);
          //114 uS: when coming from idle, i guess this is OK. 
          PFS_TOGGLE_PIN;
          if (SUCCESS == error){
            setState(S_TX_READY);
          } else {
            setState(S_ERROR_3);
          }
          //2.75 uS
          PFS_TOGGLE_PIN;
  
          captureMode = MSP430TIMER_CM_RISING;
          call SynchCapture.captureRisingEdge();
  //        printf("TA0CTL   %x\r\n", TA0CTL);
  //        printf("TA0CCTL3 %x\r\n", TA0CCTL3);
  //        printf("IOCFG1   %x\r\n", call HplMsp430Rf1aIf.readRegister(IOCFG1));
          break;
        case RF1A_OM_RX:
          //0.25 uS
          PFS_TOGGLE_PIN;
//          printf("RX from %s\r\n", decodeStatus());
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
//            //TODO: YOU CANNOT LEAVE THIS IN
//            printf("1");
            setState(S_RX_READY);
//            printf("PFS1  %s\r\n", decodeStatus());
          } else {
            printf("Error %s\r\n", decodeError(error));
            setState(S_ERROR_4);
          }
          //3.75 uS
          PFS_TOGGLE_PIN;
          break;
        default:
          setState(S_ERROR_1);
          return;
      }
    } else if (checkState(S_OFF)){
      //sometimes see this after wdtpw reset
      PFS_CLEAR_PIN;
      return;
    } else if (checkState(S_INACTIVE)){
      //nothing else to do, just reschedule alarm.
    } else {
      setState(S_ERROR_5);
      return;
    }
    printf_TDMA_SS("pfs1\r\n");
    printf_PFS("pfs1 %lu %lu: ", 
      call PrepareFrameStartAlarm.getAlarm(), 
      s_frameLen + signal TDMAPhySchedule.getFrameAdjustment(frameNum));
    call PrepareFrameStartAlarm.startAt(
      call PrepareFrameStartAlarm.getAlarm(), 
      s_frameLen + signal TDMAPhySchedule.getFrameAdjustment(frameNum));
    printf_PFS("%lu\r\n",
      call PrepareFrameStartAlarm.getAlarm());
    //16 uS
    PFS_SET_PIN;
    PFS_CLEAR_PIN;
  }

  /**
   * S_RX_READY: radio is in receive mode, frame has not yet started.
   *    FWA.fired / resumeIdleMode -> S_IDLE
   */
  async event void FrameWaitAlarm.fired(){
//    uint32_t now = call FrameWaitAlarm.getNow();
//    printf("At %lu (%lx) fwa.f %lu (%lx)\r\n",
//      now, now,
//      call FrameWaitAlarm.getAlarm(),
//      call FrameWaitAlarm.getAlarm());
//
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
//      printf("fw %s\r\n", decodeStatus());
      error = call Rf1aPhysical.resumeIdleMode();
      FW_TOGGLE_PIN;
//      printf("T.O\r\n");
      if (error == SUCCESS){
        //resumeIdle alone seems to put us into a stuck state. not
        //  sure why. Radio stays in S_IDLE when we call
        //  setReceiveBuffer in pfs.f.
        error = call Rf1aPhysical.setReceiveBuffer(0, 0, RF1A_OM_IDLE);
        if (error == SUCCESS){
          setState(S_IDLE);
        } else {
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
   * S_RX_READY: radio is in receive mode, frame has not yet started.
   *    FrameStartAlarm.fired / start frameWaitAlarm -> S_RX_READY
   *
   * S_TX_READY:
   *    FS.fired / call phy.sendNow(signal TDMA.getPacket()) 
   *      -> S_TRANSMITTING
   *
   */
  async event void FrameStartAlarm.fired(){
    error_t error;
    if(call FrameStartAlarm.getNow() < call FrameStartAlarm.getAlarm()){
      printf_PFS_FREAKOUT("FS EARLY");
      call FrameStartAlarm.startAt(
        call FrameStartAlarm.getAlarm() - s_frameLen, 
        s_frameLen);
      return;
    }    
    FS_CYCLE_TOGGLE_PIN;
    //0.25 uS
    TX_SET_PIN;
    FS_SET_PIN;
//    printf("FS %u %lu (%lu)\r\n", frameNum, 
//      call FrameStartAlarm.getNow(), 
//      call FrameStartAlarm.getAlarm());
    if (checkState(S_TX_READY)){
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
        signal CXTDMA.sendDone(0,0, frameNum, error);
      }
      //0.5 uS
      FS_TOGGLE_PIN;
    } else if (checkState(S_RX_READY)){
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
    } else {
      setState(S_ERROR_8);
    }
    lastFsa = call FrameStartAlarm.getAlarm();
    //0.5 uS
    FS_TOGGLE_PIN;
    if (! inError()){
      call FrameStartAlarm.startAt(lastFsa,
        s_frameLen 
        + signal TDMAPhySchedule.getFrameAdjustment(frameNum));
    }
    //16 uS
    FS_SET_PIN;
    FS_CLEAR_PIN;
    TX_CLEAR_PIN;
  }

  async event bool Rf1aPhysical.getPacket(uint8_t** buffer, 
      uint8_t* len){
    bool ret = signal CXTDMA.getPacket((message_t**)buffer, len, frameNum);    
    tx_msg = (message_t*)(*buffer);

    call CXPacket.incCount(tx_msg);
    *len += sizeof(rf1a_ieee154_t);
    return ret;
  }

  /**
   * S_RX_READY: radio is in receive mode, frame has not yet started.
   *   FSCapture.captured() / signal frameStarted(call
   *     FSCapture.event()),  call FWA.stop() -> S_RECEIVING
   */
  async event void SynchCapture.captured(uint16_t time){
    uint32_t fst; 
    uint32_t capture;
//    printf("cm %x\r\n", captureMode);
    SC_SET_PIN;
    fst = call FrameStartAlarm.getNow();
    //There is a ~9.25 uS delay between the SFD signal at the sender and
    //  at the receiver. So, we need to adjust the capture time
    //  accordingly.
    //This is bizarre to me: it should be *subtracting* from time, but
    //  that had the opposite effect. 
    time += SFD_PROCESSING_DELAY;

    //to put into 32-bit time scale, keep upper 16 bits of 32-bit
    //  counter. 
    //correct for overflow: will be visible if the capture time is
    //  larger than the current lower 16 bits of the 32-bit counter.
    //  This assumes that the 16-bit synch capture timer overflows at
    //  most once before this event runs (hopefully true, about 10 ms
    //  at 6.5 Mhz)
    if (time > (fst & 0x0000ffff)){
      fst  -= 0x00010000;
    } 
    capture = (fst & 0xffff0000) | time;
    //1 uS
    SC_TOGGLE_PIN;

    if (captureMode == MSP430TIMER_CM_RISING){
      //set the tx timestamp if we are the origin
      //  and this is the first transmission.
      if (tx_msg != NULL && (call CXPacket.source(tx_msg) == TOS_NODE_ID) 
          && (call CXPacket.count(tx_msg)) == 1 ){
        call CXPacket.setTimestamp(tx_msg, capture);
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
        call FrameWaitAlarm.stop();
        setState(S_RECEIVING);
        signal TDMAPhySchedule.frameStarted(lastRECapture, frameNum);
      } else if (checkState(S_TRANSMITTING)){
        //TODO: revisit the self-adjustment logic here.
//        int32_t delta = lastRECapture - 
//          (lastFsa + SFD_TIME );
//        printf("d %ld\r\n", delta);
//        call FrameStartAlarm.startAt(lastFsa + delta, s_frameLen);
        signal TDMAPhySchedule.frameStarted(lastRECapture, frameNum);
      } else {
        setState(S_ERROR_9);
      }
      //7 uS
      SC_TOGGLE_PIN;
    } else if (captureMode == MSP430TIMER_CM_FALLING){
      lastFECapture = capture;
      atomic{
        captureMode = MSP430TIMER_CM_NONE;
        call SynchCapture.disable();
      }
      if (checkState(S_RECEIVING)){
        //TODO: record packet duration? not sure if we need this.
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
    //we see this if we're doing an automatic switch from RX to FSTXON
    //or from FSTXON to RX.
    while(call Rf1aStatus.get() == RF1A_S_SETTLING){ };
    switch (call Rf1aStatus.get()){
      case RF1A_S_IDLE:
        setState(S_IDLE);
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

  /**
   * S_RECEIVING: frame has started, expecting data.
   *   phy.receiveDone / signal and swap -> S_RX_CLEANUP
   */
  async event void Rf1aPhysical.receiveDone (uint8_t* buffer,
                                             unsigned int count,
                                             int result) {
    if (checkState(S_RECEIVING)){
      if (SUCCESS == result){
        setState(S_RX_CLEANUP);
        atomic{
          call CXPacket.setCount((message_t*)buffer, 
            call CXPacket.count((message_t*)buffer) +1);
          call CXPacketMetadata.setReceivedAt((message_t*)buffer,
            lastRECapture);
          call CXPacketMetadata.setFrameNum((message_t*)buffer,
            frameNum);
          rx_msg = signal CXTDMA.receive((message_t*)buffer, count,
            frameNum, lastRECapture);
        }
        completeCleanup();
      } else {
        setState(S_ERROR_c);
      }
    } else {
      setState(S_ERROR_d);
    }
  }

  /**
   * S_TRANSMITTING:
   *   phy.sendDone / signal sendDone -> S_TX_CLEANUP 
   */
  async event void Rf1aPhysical.sendDone (uint8_t* buffer, 
      uint8_t len, int result) { 
    tx_msg = NULL;
    if(checkState(S_TRANSMITTING)){
      setState(S_TX_CLEANUP);
      signal CXTDMA.sendDone((message_t*)buffer, len, frameNum, result);
      completeCleanup();
    } else {
      setState(S_ERROR_e);
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
  
  command error_t TDMAPhySchedule.setSchedule(uint32_t startAt,
      uint16_t atFrameNum, uint32_t frameLen,
      uint32_t fwCheckLen, uint16_t activeFrames, 
      uint16_t inactiveFrames, uint8_t symbolRate){
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
      uint32_t firstDelta;
      call PrepareFrameStartAlarm.stop();
      call FrameStartAlarm.stop();
      printf_TDMA_SS("SS@%lu: %lu %u %lu %lu %u %u %x\r\n", 
        call FrameStartAlarm.getNow(), 
        startAt, atFrameNum,
        frameLen, fwCheckLen, activeFrames, inactiveFrames, symbolRate);

      atomic{
        SS_TOGGLE_PIN;
        firstDelta = frameLen;
        //make sure that base time is in the past.
        while(startAt > call FrameStartAlarm.getNow()){
          printf_TDMA_SS("s");
          startAt -= frameLen;
          firstDelta += frameLen;
        }
        SS_TOGGLE_PIN;

        //if target is in the past, we need to jump ahead by some
        //  frames.
        while ( (startAt + firstDelta) < call FrameStartAlarm.getNow()){
          atFrameNum = (1+atFrameNum) % (activeFrames + inactiveFrames);
          firstDelta += frameLen;
          //also apply corrections to the fast-forward.
          firstDelta += signal TDMAPhySchedule.getFrameAdjustment(atFrameNum);
          printf_TDMA_SS("d");
        }

        SS_TOGGLE_PIN;
        s_frameStart = startAt;
        s_frameLen = frameLen;
        s_fwCheckLen = fwCheckLen;
        s_activeFrames = activeFrames;
        s_inactiveFrames = inactiveFrames;
        if (atFrameNum == 0){
          printf_TDMA_SS("w");
          atFrameNum = activeFrames + inactiveFrames;
        }
        frameNum = atFrameNum - 1;
        SS_TOGGLE_PIN;
      }
      //reschedule alarms based on these settings.
      // we want atFrameNum to come up at startAt. 
      //so: pfs will fire at startAt. At that time, frameNum will get
      //  incremented
      //TODO: check for over/under flows
      printf_TDMA_SS("Now %lu base %lu delta %lu (%lu %lu) at %u\r\n", 
        call PrepareFrameStartAlarm.getNow(), s_frameStart,
        firstDelta, 
        firstDelta-PFS_SLACK-SFD_TIME, 
        firstDelta - SFD_TIME, 
        frameNum);

      SS_TOGGLE_PIN;

      call PrepareFrameStartAlarm.stop();
      call FrameStartAlarm.stop();
      printf_TDMA_SS("pfs0\r\n");
      printf_PFS("pfs0 %lu %lu:", s_frameStart, firstDelta - PFS_SLACK
      - SFD_TIME);
      call PrepareFrameStartAlarm.startAt(s_frameStart,
        firstDelta - PFS_SLACK - SFD_TIME);
      printf_PFS("%lu\r\n", call PrepareFrameStartAlarm.getAlarm());
      printf_TDMA_SS("GA: %lu \r\n", call PrepareFrameStartAlarm.getAlarm());
      call FrameStartAlarm.startAt(
        s_frameStart, 
        firstDelta - SFD_TIME);
      SS_CLEAR_PIN;
      atomic{
        if (frameNum % 2){
          PFS_CYCLE_SET_PIN;
          FS_CYCLE_SET_PIN;
        }else{
          PFS_CYCLE_CLEAR_PIN;
          FS_CYCLE_CLEAR_PIN;
        }
      }
      return SUCCESS;
    } else {
      setState(S_ERROR_2);
      SS_CLEAR_PIN;
      return FAIL;
    }
  }

  async event void Rf1aPhysical.frameStarted () { 
//    printf("rp.fs\r\n");
    //ignored: we use the GDO timer capture for this.
  }

  //BEGIN unimplemented
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
  /**
    x S_OFF: off/not duty cycled
      x SplitControl.start / resource.request -> S_STARTING
    
    x S_STARTING: radio core starting up/calibrating
      x resource.granted / -  -> S_IDLE

    x S_IDLE: in the part of a frame where no data is expected.
      x PFS.fired + !isTX / setReceiveBuffer + startReception -> S_RX_STARTING
      x PFS.fired + isTX  / startTransmit(FSTXON) -> S_TX_STARTING
    
    ~ S_RX_STARTING: setting up for cs/fs check
      ~ phy.currentStatus(RX) / call FrameWaitAlarm.startAt(call FS.alarm(),
        fwCheckLen) -> S_RX_READY

    x S_RX_READY: radio is in receive mode, frame has not yet started.
      ~ phy.carrierSense / record time -> S_RX_READY
      x FSCapture.captured() / signal frameStarted(call
         FSCapture.event()),  call FWA.stop() -> S_RECEIVING
      x FWA.fired / resumeIdleMode -> S_IDLE

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
    
    x S_TX_READY:
    x  FS.fired / call phy.sendNow(signal TDMA.getPacket()) 
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

}
/* 
 * Local Variables:
 * mode: c
 * End:
 */
