/**
 * Implementation of protocol-independent TDMA.
 *  - Duty cycling
 *  - request data at frame start
 */
 #include "CXTDMA.h"

module CXTDMAPhysicalP {
  provides interface SplitControl;
  provides interface CXTDMA;

  uses interface HplMsp430Rf1aIf;
  uses interface Resource;
  uses interface Rf1aPhysical;
  uses interface Rf1aPhysicalMetadata;
  uses interface Rf1aStatus;

  uses interface Rf1aPacket;

  uses interface Alarm<TMicro, uint32_t> as PrepareFrameStartAlarm;
  uses interface Alarm<TMicro, uint32_t> as FrameStartAlarm;
  uses interface Alarm<TMicro, uint32_t> as FrameWaitAlarm;
  uses interface Msp430Capture as SynchCapture;
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

    S_OFF = 0x00,
    S_STARTING = 0x01,
    S_INACTIVE = 0x02,
    S_IDLE = 0x03,

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

  message_t rx_msg_internal;
  message_t* rx_msg = &rx_msg_internal;
  uint8_t rx_count; 

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

  void printStatus(){
    printf("* Core: %s\n\r", decodeStatus());
    printf("--------\n\r");
  }

  task void printStatusTask(){
    printStatus();
  }

  bool checkState(uint8_t s){ atomic return (state == s); }
  void setState(uint8_t s){
    atomic {
      #ifdef DEBUG_CX_TDMA_P_STATE
      printf("[%x->%x]\n\r", state, s);
      #endif
      #ifdef DEBUG_CX_TDMA_P_STATE_ERROR
      if (ERROR_MASK == (s & ERROR_MASK)){
        P2OUT |= BIT4;
        printf("[%x->%x]\n\r", state, s);
      }
      #endif
      state = s;
    }
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
        call SynchCapture.setEdge(captureMode);
      }
      call SynchCapture.setSynchronous(TRUE);
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
      printStatus();
      atomic {
        frameNum = 0;
      }

      //If no schedule provided, provide some defaults which will
      //  basically keep us waiting until something shows up that we
      //  can synch on.
      if (s_frameStart == 0){
        atomic{
          s_frameStart = (call PrepareFrameStartAlarm.getNow() +
            PFS_SLACK);
          s_frameLen = DEFAULT_TDMA_FRAME_LEN;
          s_fwCheckLen = DEFAULT_TDMA_FW_CHECK_LEN;
          s_activeFrames = DEFAULT_TDMA_ACTIVE_FRAMES;
          s_inactiveFrames = DEFAULT_TDMA_INACTIVE_FRAMES;
        }
      }
      
      call PrepareFrameStartAlarm.startAt(s_frameStart - PFS_SLACK,
        s_frameLen);
      //TODO: any SW clock-tuning should be done here.
      call FrameStartAlarm.startAt(s_frameStart, s_frameLen - SFD_TIME);

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
    if (frameNum > s_activeFrames){
      if (SUCCESS == call Resource.release()){
        setState(S_INACTIVE);
      } else { 
        setState(S_ERROR);
      }
    } else if (frameNum == s_activeFrames + s_inactiveFrames - 1){
      if (SUCCESS == call Resource.request()){
        setState(S_STARTING);
      } else {
        setState(S_ERROR);
      }
    } else {
      if (checkState(S_IDLE)){
        if (signal CXTDMA.isTXFrame(frameNum + 1)){
          error = call Rf1aPhysical.startSend(FALSE, signal
            CXTDMA.isTXFrame(frameNum + 2));
          if (SUCCESS == error){
            setState(S_TX_READY);
          } else {
            setState(S_ERROR);
          }
        } else {
          error = call Rf1aPhysical.setReceiveBuffer(
            (uint8_t*)(rx_msg->header),
            TOSH_DATA_LENGTH + sizeof(message_header_t),
            signal CXTDMA.isTXFrame(frameNum+2));
          if (SUCCESS == error){
            atomic {
              captureMode = MSP430TIMER_CM_RISING;
              call SynchCapture.setEdge(captureMode);
            }
            setState(S_RX_READY);
          } else {
            setState(S_ERROR);
          }
        }
        call PrepareFrameStartAlarm.startAt(
          call PrepareFrameStartAlarm.getAlarm(), s_frameLen);
      } else {
        setState(S_ERROR);
      }
    }
  }

  /**
   * S_RX_READY: radio is in receive mode, frame has not yet started.
   *    FWA.fired / resumeIdleMode -> S_IDLE
   */
  async event void FrameWaitAlarm.fired(){
    if (checkState(S_RX_READY)){
      error_t error = call Rf1aPhysical.resumeIdleMode();
      setState(S_IDLE);
    } else {
      setState(S_ERROR);
    }
  }

  /**
   * S_RX_READY: radio is in receive mode, frame has not yet started.
   *    FrameStartAlarm.fired / start frameWaitAlarm -> S_RX_READY
   */
  async event void FrameStartAlarm.fired(){
    call FrameWaitAlarm.startAt(call FrameStartAlarm.getAlarm(),
      s_fwCheckLen);
    call FrameStartAlarm.startAt(call FrameStartAlarm.getAlarm(),
      s_frameLen);
  }

  /**
   * S_RX_READY: radio is in receive mode, frame has not yet started.
   *   FSCapture.captured() / signal frameStarted(call
   *     FSCapture.event()),  call FWA.stop() -> S_RECEIVING
   */
  async event void SynchCapture.captured(uint16_t time){
    uint32_t fst = call FrameStartAlarm.getNow();
    uint32_t captureTime;
    //to put into 32-bit time scale, keep upper 16 bits of 32-bit
    //  counter. 
    //correct for overflow: will be visible if the capture time is
    //  larger than the current lower 16 bits of the 32-bit counter
    if (time > (fst & 0x0000ffff)){
      time -= 0x0000ffff;
      fst  -= 0x00010000;
    } 
    captureTime = (fst & 0xffff0000) | time;

    if (captureMode == MSP430TIMER_CM_RISING){
      atomic{
        captureMode = MSP430TIMER_CM_FALLING;
        call SynchCapture.setEdge(captureMode);
      }
      if (checkState(S_RX_READY)){
        //TODO: need to call capture.event or clear overflow manually?
        call FrameWaitAlarm.stop();
        signal CXTDMA.frameStarted(captureTime);
      } else if (checkState(S_TRANSMITTING)){
        //TODO: record actual start, not sure if this is needed.
      } else {
        setState(S_ERROR);
      }
    } else if (captureMode == MSP430TIMER_CM_FALLING){
      atomic{
        captureMode = MSP430TIMER_CM_NONE;
        call SynchCapture.setEdge(captureMode);
      }
      if (checkState(S_RECEIVING)){
        //TODO: record packet duration? not sure if we need this.
      }
    } else {
      setState(S_ERROR);
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
          rx_msg = signal CXTDMA.receive((message_t*)buffer, count);
        }
        completeCleanup();
      } else {
        setState(S_ERROR);
      }
    } else {
      setState(S_ERROR);
    }
  }


  //BEGIN unimplemented
  command error_t SplitControl.stop(){
    //TODO: set scOffPending flag
    return FAIL;
  }

  command error_t CXTDMA.setSchedule(uint32_t startAt, uint32_t frameLen,
      uint32_t fwCheckLen, uint16_t activeFrames, uint16_t inactiveFrames){
    return FAIL;
  }

  async event void Rf1aPhysical.frameStarted () { 
    printf("!fs\n\r");
  }

  async event void Rf1aPhysical.carrierSense () { 
//    printf("!cs\n\r");
  }
  async event void Rf1aPhysical.sendDone (int result) { 
    printf("!sd\n\r");
  }
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

}
/* 
 * Local Variables:
 * mode: c
 * End:
 */
