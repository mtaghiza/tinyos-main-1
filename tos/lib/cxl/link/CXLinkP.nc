
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

    S_TXTONE = 4,
    S_RXTONE = 5,
    S_FWDTONE = 6,
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

  //------------ Tone control
  /**
   * Tone transmission flow:
   * - state -> TXTONE, no time ref
   * - switch to tone channel
   * - configure radio to non-whiten/non-encode, offmode=IDLE
   * - send immediately
   */
  //tone control vars
  uint8_t toneIndex;
 
  //tone control forward declarations
  task void handleSendDone();
  bool readyForward(message_t* msg);
  error_t subsend(message_t* msg, uint8_t len);

  command error_t CXLink.txTone(uint8_t channel){
    state = S_TXTONE;
    aSfdCapture = 0;
  }

  event void DelayedSend.sendReady(){
    if (aSfdCapture){
      call FastAlarm.startAt(aSfdCapture, FRAMELEN_FAST + sfdAdjust);
    }else{
      call DelayedSend.startSend();
    }
  }

  async event void Rf1aPhysical.sendDone (int result) { 
    sfdAdjust = TX_SFD_ADJUST;
    post handleSendDone();
  }

  task void handleSendDone(){
    if (state == S_TX || state == S_FWD){
      if (readyForward(fwdMsg)){
        subsend(fwdMsg, fwdLen);
      } else {
        if (state == S_TX){
          signal Send.sendDone(fwdMsg, SUCCESS);
          //TODO: turn off xt2
        } else {
          //TODO: fill in vars
          rxMsg = signal Receive.receive(rxMsg, NULL, 0);
          signal CXLink.rxDone();
        }
      }
    }else if (state == S_FWDTONE){
      signal CXLink.toneReceived(TRUE);
    } else if (state == S_TXTONE){
      signal CXLink.toneSent();
    }
  }

  /**
   * Tone reception flow
   * - state -> RXTONE
   * - switch channel
   * - start timeout alarm
   * - configure radio as above, plus...
   *   - set rx buffer to validation buffer
   *   - set buffer length to length of validation field
   *   - set fifo threshold to low value
   *   - enable synch capture 
   * - timeout? signal toneReceived(FALSE) and clean up.
   * - receiveStarted: convert length to position in tone reference
   *   packet.
   * - receiveBufferFilled: kill reception and validate the received
   *   value against its companion in the reference packet
   * - received tone is valid? use rx time of tone to set time where
   *   it should be retransmitted.
   */
  //Tone RX forward declarations
  uint8_t convertLengthToIndex(uint8_t length);
  task void toneFwd();

  //Tone RX vars
  uint8_t validationVal;

  command error_t CXLink.rxTone(uint32_t timeout, uint8_t channel){
    state = S_RXTONE;
    //set timeout
    //switch to tone channel
    //start receiving: don't whiten, don't decode, low RXFIFO threshold, buffer length =
    //V_LEN, RX_OFF_MODE = FSTXON
    // set receive buffer to &validationVal;
    return FAIL;
  }

  async event void FastAlarm.fired(){
    if (state == S_FWD || state == S_FWDTONE){
      call DelayedSend.startSend();
    } else if (state == S_RX){
      //TODO: pushback alarm if CS was high
      call Rf1aPhysical.resumeIdleMode(RF1A_OM_IDLE);
      signal CXLink.rxDone();
    } else if (state == S_RXTONE){
      //TODO: pushback alarm if CS was high
      call Rf1aPhysical.resumeIdleMode(RF1A_OM_IDLE);
      signal CXLink.toneReceived(FALSE);
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
    if (state == S_RXTONE){
      //length should tell us where we are in the packet.
      toneIndex = convertLengthToIndex(length);
    }
  }

  uint8_t convertLengthToIndex(uint8_t length){
    //Packet looks like
    // (P S L) V | P S L V | ... | CRC

    //P_LEN: preamble length
    //S_LEN: synch length
    //L_LEN: length byte length
    //V_LEN: validation length
    //T_BLOCKS: number of blocks 
    

    //L = (#blocks after this) * (block len) + VALIDATION_LEN
    //blocks_after = (L-VALIDATION_LEN)/block_len
    //&L: (T_BLOCKS*block_len) - ((blocks_after)*B_LEN) - (V + L)
    
    // 10 blocks, P_LEN = 4, S_LEN = 4, L_LEN = 1, V_LEN = 1
    // B_LEN = 1+1+4+4 = 10
    // total: 100 - (P + S + L)  = 91
    //receive len 91:
    // (91 - 1) /10 = 9 blocks after
    // &L: 100 - 90 - 2  = 8
    // &V: 8 + V_LEN
    //          *
    // PPPPSSSSLV
  }

  async event void Rf1aPhysical.receiveBufferFilled(uint8_t* buffer, unsigned int count) { 
    if (state == S_RXTONE){
      //TODO: kill reception
      post toneFwd();
    }
  }

  task void toneFwd(){
    if (validationVal == tonePacket[toneIndex]){
      state = S_FWDTONE;
      //TODO: start sending packet: 
      // - compute the real start index: probably toneIndex + 2*B_LEN
      // - set FastAlarm accordingly.
    }else{
      call Rf1aPhysical.resumeIdleMode(RF1A_OM_IDLE);
      signal CXLink.toneReceived(FALSE);
    }
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
    atomic{
      //TODO: record metadata about reception: hop count, 32k
      //  timestamp
      len = rxLen;
    }
    if (state == S_RX){
      if (readyForward(rxMsg)){
        state = S_FWD;
        fwdMsg = rxMsg;
        fwdLen = len;
        subsend(fwdMsg, fwdLen);
      }else{
        state = S_IDLE;
        //TODO: idle (sleep?) the radio
        //TODO: turn off XT2.
        //TODO: fill in params
        rxMsg = signal Receive.receive(rxMsg, NULL, len);
        signal CXLink.rxDone();
      }
    }else if (state == S_RXTONE){
      state = S_IDLE;
      signal CXLink.toneReceived(TRUE);
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
  
}
