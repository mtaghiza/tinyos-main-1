module CXLinkP {
  uses interface SplitControl;
  uses interface Resource;
  uses interface Rf1aPhysical;
  uses interface DelayedSend;
  uses interface GpioCapture as SynchCapture;
  uses interface Alarm<TMicro, uint32_t> as FastAlarm;
  uses interface Timer<T32khz> as FrameTimer;

  provides interface Receive;
  provides interface Send;

} implementation {
  message_t msg_internal;
  message_t* rxMsg = &msg_internal;
  message_t* fwdMsg;
  enum {
    S_SLEEP = 0,

    S_RX = 1,
    S_TX = 2,
    S_FWD = 3,

    S_TXTONE = 4,
    S_RXTONE = 5,
    S_FWDTONE = 6,
  };

  uint8_t state = S_SLEEP;

  command error_t CXLink.sleep(){
    return call Rf1aPhysical.sleep();
  }

  command error_t Send.send(message_t* msg, uint8_t len){
    //switch to data channel if not already on it
    aSfdCapture = 0;
    fwdMsg = msg;
    fwdLen = len;
    return subsend(msg, len);
  }

  error_t subsend(message_t* msg, uint8_t len){
    error_t error = call Rf1aPhysical.startTransmission(FALSE, TRUE);
    if (error == SUCCESS) {
      //TODO: off mode should be FSTXON if we're forwarding
      error = call Rf1aPhysical.send(msg, len, RF1A_OM_IDLE);
    }
    return error;
  }

  event void DelayedSend.sendReady(){
    if (aSfdCapture){
      call FastAlarm.startAt(aSfdCapture, FRAMELEN_FAST + sfdAdjust);
    }else{
      call DelayedSend.startSend();
    }
  }

  bool readyForward(message_t* msg){
    //increment hop-count
    //decrement TTL
    //return TTL > 0
    return FALSE;
  }

  task void handleSendDone(){
    if (state == S_TX || state == S_FWD){
      if (readyForward(fwdMsg)){
        subsend(fwdMsg, fwdLen);
      } else {
        if (state == S_TX){
          signal Send.sendDone();
          //TODO: turn off xt2
        } else {
          rxMsg = signal Receive.receive(rxMsg);
          signal CXLink.rxDone();
        }
      }
    }else if (state == S_FWDTONE){
      signal CXLink.toneReceived(TRUE);
    } else if (state == S_TXTONE){
      signal CXLink.toneSent();
    }
  }

  async event void Rf1aPhysical.sendDone (int result) { 
    sfdAdjust = TX_SFD_ADJUST;
    post handleSendDone();
  }

  command error_t CXLink.rx(uint32_t timeout){
    //switch to data channel if not already on it
    //TODO: off mode should be FSTXON
    error_t error = call Rf1aPhysical.setReceiveBuffer(rxMsg, 
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
        rxMsg = signal Receive.receive(rxMsg, len);
        signal CXLink.rxDone();
      }
    }else if (state == S_RXTONE){
      state = S_IDLE;
      signal CXLink.toneReceived(TRUE);
    }
  }

  async event void Rf1aPhysical.receiveDone (uint8_t* buffer,
                                             unsigned int count,
                                             int result) {
    sfdAdjust = RX_SFD_ADJUST;
    rxLen = count;
    post handleReception();
  } 

  async event void FastAlarm.fired(){
    if (state == S_RX){
      //TODO: pushback alarm if CS was high
      call Rf1aPhysical.resumeIdleMode(RF1A_OM_IDLE);
      signal CXLink.rxDone();
    } else if (state == S_FWD){
      call DelayedSend.startSend();
    } else if (state == S_RXTONE){
      signal CXLink.toneReceived(FALSE);
    }
  }

  //------------ Tone control
  command error_t CXLink.txTone(uint8_t depth){
    state = S_TXTONE;
    //switch to tone channel
    //start sending tone packet immediately: don't whiten, don't
    //encode.
  }

  command error_t CXLink.rxTone(uint32_t timeout){
    state = S_RXTONE;
    //switch to tone channel
    //start receiving: don't whiten, don't decode, low RXFIFO threshold, buffer length =
    //V_LEN, RX_OFF_MODE = FSTXON
    // set receive buffer to &validationVal;

  }
  
  task void toneFwd(){
    if (validationVal == tonePacket[toneIndex]){
      //TODO: start sending packet: 
      // - compute the real start index: probably toneIndex + 2*B_LEN
      // - set FastAlarm accordingly.
    }
  }

  async event void Rf1aPhysical.receiveBufferFilled[uint8_t client] (uint8_t* buffer, unsigned int count) { 
    if (state == S_RXTONE){
      //TODO: kill reception
      post toneFwd();
    }
  }


  uint8_t convertLengthToIndex(){
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

  async event void Rf1aPhysical.receiveStarted[uint8_t client] (unsigned int length) { 
    if (state == S_RXTONE){
      //length should tell us where we are in the packet.
      toneLookupIndex = convertLengthToIndex(length);
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
    signal SplitControl.startDone(SUCCESS);
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
