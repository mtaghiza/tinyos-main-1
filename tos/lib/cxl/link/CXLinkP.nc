
 #include "CXLink.h"
module CXLinkP {
  provides interface SplitControl;
  uses interface Resource;

  uses interface Rf1aPhysical;
  uses interface DelayedSend;

  uses interface GpioCapture as SynchCapture;
  uses interface Msp430XV2ClockControl;
  uses interface Alarm<TMicro, uint32_t> as FastAlarm;

  provides interface Receive;
  provides interface Send;
  provides interface CXLink;

  uses interface Pool<message_t>;

  uses interface Packet as PacketBody;
  uses interface Packet as PacketHeader;

  uses interface Rf1aPhysicalMetadata;
} implementation {
  message_t* rxMsg;
  uint8_t rxLen;
  message_t* fwdMsg;
  uint8_t fwdLen;

  enum {
    S_SLEEP = 0,

    S_RX = 1,
    S_TX = 2,
    S_FWD = 3,

    S_IDLE = 7,
  };

  uint8_t state = S_SLEEP;
  uint32_t aSfdCapture;
  int32_t sfdAdjust;
  
  /**
   *  Immediately sleep the radio. 
   */
  command error_t CXLink.sleep(){
    //TODO: verify that we're not active (either in the process of
    //forwarding or during an active reception event)
    return call Rf1aPhysical.sleep();
  }

  /**
   *  Put the radio into RX mode (->FSTXON), and start wait timeout.
   *  Set up SFD capture/etc.
   */
  command error_t CXLink.rx(uint32_t timeout){
    //switch to data channel if not already on it
    //TODO: off mode should be FSTXON
    error_t error = call Rf1aPhysical.setReceiveBuffer((uint8_t*)rxMsg, 
      TOSH_DATA_LENGTH + sizeof(message_header_t), TRUE);

    if (SUCCESS == error){
      if (! call Msp430XV2ClockControl.isMicroTimerRunning()){
        call Msp430XV2ClockControl.startMicroTimer();
      }
      atomic{
        call FastAlarm.start(timeout);
        call SynchCapture.captureRisingEdge();
        state = S_RX;
      }
    }
    return error;
  }

  task void handleSendDone();
  bool readyForward(message_t* msg);
  error_t subsend(message_t* msg, uint8_t len);

  command error_t CXLink.txTone(uint8_t channel){
    return FAIL;
  }

  event void DelayedSend.sendReady(){
    if (aSfdCapture){
      atomic call FastAlarm.startAt(aSfdCapture, FRAMELEN_FAST + sfdAdjust);
    }else{
      call DelayedSend.startSend();
    }
  }

  async event void Rf1aPhysical.sendDone (int result) { 
    atomic sfdAdjust = TX_SFD_ADJUST;
    post handleSendDone();
  }

  task void handleSendDone(){
    uint8_t localState;
    atomic localState = state;
    if (localState == S_TX || localState == S_FWD){
      if (readyForward(fwdMsg)){
        subsend(fwdMsg, fwdLen);
      } else {
        if (localState == S_TX){
          signal Send.sendDone(fwdMsg, SUCCESS);
          //TODO: turn off xt2
        } else {
          //TODO: fill in vars
          rxMsg = signal Receive.receive(rxMsg, NULL, 0);
          signal CXLink.rxDone();
        }
      }
    }
  }

  command error_t CXLink.rxTone(uint32_t timeout, uint8_t channel){
    return FAIL;
  }
  
  task void signalRXDone(){
    signal CXLink.rxDone();
  }

  async event void FastAlarm.fired(){
    if (state == S_FWD){
      call DelayedSend.startSend();
    } else if (state == S_RX){
      //TODO: pushback alarm if CS was high
      call Rf1aPhysical.resumeIdleMode(RF1A_OM_IDLE);
      post signalRXDone();
    } else {
      //TODO: handle unexpected state
    }
  }

  async event void SynchCapture.captured(uint16_t time){
    uint32_t ft = call FastAlarm.getNow();
    call FastAlarm.stop();
    if (time > (ft & 0x0000ffff)){
      ft  -= 0x00010000;
    }
    //expand to 32 bits
    aSfdCapture = (ft & 0xffff0000) | time;
    call SynchCapture.disable();
  }

  async event void Rf1aPhysical.receiveStarted(unsigned int length) { 
  }

  async event void Rf1aPhysical.receiveBufferFilled(uint8_t* buffer, unsigned int count) { 
  }


  //--------- RX/TX/FWD flow
  /**
   * Overall:
   * - receive/send switch the radio into the relevant active mode,
   *   offmode = FSTXON, enable synch capture.
   * - at SFD capture, record time of SFD.
   * - Upon reception/completion of send, update the packet headers
   *   and schedule the next forwarding step.
   * - When TTL reaches 0, signal the relevant receive/sendDone event.
   */
  task void handleReception();

  /**
   * Set up the radio to transmit the provided packet immediately.
   */
  command error_t Send.send(message_t* msg, uint8_t len){
    aSfdCapture = 0;
    fwdMsg = msg;
    fwdLen = len;
    return subsend(msg, len);
  }
  
  error_t subsend(message_t* msg, uint8_t len){
    //TODO: start micro timer if not running
    error_t error = call Rf1aPhysical.startTransmission(FALSE, TRUE);
    if (error == SUCCESS) {
      //TODO: off mode should be FSTXON if we're forwarding
      //TODO: enable synch capture.
      error = call Rf1aPhysical.send((uint8_t*)msg, len, RF1A_OM_IDLE);
    }
    return error;
  }

  /**
   * update header fields of packet and return whether or not
   * forwarding is complete.
   */
  bool readyForward(message_t* msg){
    //increment hop-count
    //decrement TTL
    //return TTL > 0
    return FALSE;
  }



  async event void Rf1aPhysical.receiveDone (uint8_t* buffer,
                                             unsigned int count,
                                             int result) {
    sfdAdjust = RX_SFD_ADJUST;
    rxLen = count;
    post handleReception();
  } 

  /**
   * Deal with the aftermath of packet reception: record
   * metadata/timing information, prepare for forwarding if needed.
   */
  task void handleReception(){
    uint8_t len;
    uint8_t localState;
    atomic{
      //TODO: record metadata about reception: hop count, 32k
      //  timestamp
      len = rxLen;
      localState = state;
    }
    if (localState == S_RX){
      if (readyForward(rxMsg)){
        atomic{
          state = S_FWD;
          fwdMsg = rxMsg;
          fwdLen = len;
        }
        subsend(fwdMsg, fwdLen);
      }else{
        atomic state = S_IDLE;
        //TODO: idle (sleep?) the radio
        //TODO: turn off XT2.
        //TODO: fill in params
        rxMsg = signal Receive.receive(rxMsg, NULL, len);
        signal CXLink.rxDone();
      }
    }else{ 
      //TODO: unexpected state
    }
  }


  //------------
  // "Easy stuff"
  command error_t SplitControl.start(){
    if (call Resource.isOwner()){
      return EALREADY;
    }else{
      return call Resource.request();
    }
  }

  event void Resource.granted(){
    rxMsg = call Pool.get();
    if (rxMsg){
      signal SplitControl.startDone(SUCCESS);
    }else {
      signal SplitControl.startDone(ENOMEM);
    }
  }

  task void signalStopDone(){
    signal SplitControl.stopDone(SUCCESS);
  }

  command error_t SplitControl.stop(){
    if (! call Resource.isOwner()){
      return EALREADY;
    }else{
      post signalStopDone();
      return call Resource.release();
    }
  }

  command void* Send.getPayload(message_t* msg, uint8_t len){
    return NULL;
  }
  command uint8_t Send.maxPayloadLength(){
    return call PacketBody.maxPayloadLength();
  }

  command error_t Send.cancel(message_t* msg){
    return FAIL;
  }

  async event void Rf1aPhysical.frameStarted () { }
  async event void Rf1aPhysical.clearChannel () { }
  async event void Rf1aPhysical.carrierSense () { }
  async event void Rf1aPhysical.released () { }

  
}
