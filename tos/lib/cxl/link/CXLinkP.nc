
 #include "CXLink.h"
 #include "CXLinkDebug.h"

module CXLinkP {
  provides interface SplitControl;
  uses interface Resource;

  uses interface Rf1aPhysical;
  uses interface DelayedSend;
  uses interface Rf1aStatus;

  uses interface GpioCapture as SynchCapture;
  uses interface Msp430XV2ClockControl;
  uses interface Alarm<TMicro, uint32_t> as FastAlarm;
  uses interface LocalTime<T32khz>; 
  uses interface LocalTime<TMilli> as LocalTimeMilli; 

  provides interface Receive;
  provides interface Send;
  provides interface CXLink;

  uses interface Pool<message_t>;

  uses interface Packet;
  uses interface CXLinkPacket;

  uses interface Rf1aPhysicalMetadata;
  uses interface ActiveMessageAddress;

  uses interface StateDump;

  uses interface GetNow<uint16_t> as LastCRC;
} implementation {
  message_t* rxMsg;
  uint8_t rxLen;
  message_t* fwdMsg;
  uint16_t sn;
  uint32_t origTimeout;

  int aTxResult;
  
  #if DL_LINK <= DL_DEBUG && DL_GLOBAL <= DL_DEBUG
  enum {
    CRC_HIST_LEN=11,
  };
  norace bool txHist[CRC_HIST_LEN];
  norace uint16_t crcHist[CRC_HIST_LEN];
  norace uint8_t crcIndex;
  norace uint8_t crcFirstPassed;
  
  void logCRCs(am_addr_t src, uint16_t psn){
    if (crcIndex){
      uint8_t i;
      for (i=crcFirstPassed ; i < crcIndex; i++ ){
        uint8_t k = crcIndex - i;
        cdbg(LINK, "CH %u %u %u %x %x\r\n", src, psn, k, txHist[i], crcHist[i]);
      }
    }
  }
  #else
  void logCRCs(am_addr_t src, uint16_t psn){}
  #endif

  enum {
    S_SLEEP = 0,

    S_RX = 1,
    S_TX = 2,
    S_FWD = 3,

    S_IDLE = 7,
  };

  uint8_t state = S_SLEEP;
  uint32_t aSfdCapture;
  uint32_t frameLen;
  bool aSynched;
  bool aCSDetected;
  bool aExtended;
  int32_t sfdAdjust;


  void doSignalRXDone();

  uint32_t fastToSlow(uint32_t fastTicks){
    //OK w.r.t overflow as long as fastTicks is 22 bits or less (0.64 seconds)
    return (FRAMELEN_SLOW*fastTicks)/FRAMELEN_FAST_NORMAL;
  }


  #if DL_LINK <= DL_ERROR && DL_GLOBAL <= DL_ERROR
  event void StateDump.dumpRequested(){
    uint8_t lState;
    bool faRunning;
    rf1a_status_e pState;
    atomic {
      lState = state;
      faRunning = call FastAlarm.isRunning();
      pState = call Rf1aStatus.get();
    }
    atomic cerror(LINK, "Link %x rxm %p fwd %p phy %x \r\n",
      lState, rxMsg, fwdMsg, pState); 
  }
  #else
  event void StateDump.dumpRequested(){
  }
  #endif

  cx_link_header_t* header(message_t* msg){
    return (call CXLinkPacket.getLinkHeader(msg));
  }

  cx_link_metadata_t* metadata(message_t* msg){
    return (call CXLinkPacket.getLinkMetadata(msg));
  }
  rf1a_metadata_t* phy(message_t* msg){
    return (call CXLinkPacket.getPhyMetadata(msg));
  }
  
  void applyTimestamp(message_t* msg){
    atomic{
      uint32_t fastRef1 = call FastAlarm.getNow();
      uint32_t slowRef = call LocalTime.get();
      uint32_t fastRef2 = call FastAlarm.getNow();
      uint32_t milliRef = call LocalTimeMilli.get();
      uint32_t fastTicks = fastRef1 + ((fastRef2-fastRef1)/2) - metadata(msg)->timeFast;
      uint32_t slowTicks = fastToSlow(fastTicks);
      uint32_t flLocal = (call CXLinkPacket.len(msg) == SHORT_PACKET) ?  FRAMELEN_FAST_SHORT : FRAMELEN_FAST_NORMAL;
      slowTicks += fastToSlow((flLocal*(metadata(msg)->rxHopCount-1)));
      if (metadata(msg)->timeFast != 0){
        metadata(msg)->time32k = slowRef - slowTicks;
        metadata(msg)->timeMilli = milliRef - (slowTicks >> 5);
      }else{
        //no SFD capture: leave timestamps set to 0.
        cwarn(LINK, "NTS\r\n");
        metadata(msg)->time32k = 0;
        metadata(msg)->timeMilli = 0;
      }
    }
  }
  
  /**
   *  Immediately sleep the radio. 
   */
  command error_t CXLink.sleep(){
    uint8_t localState;
    atomic localState = state;
    if (localState == S_TX || localState == S_FWD){
      return EBUSY;
    }else{
      error_t err = call Rf1aPhysical.resumeIdleMode(RF1A_OM_IDLE);
      if (err != SUCCESS){
        cerror(LINK, "LINK.sleep: p.rim %x\r\n", err);
      }
      err = call Rf1aPhysical.setReceiveBuffer(NULL, 0, TRUE,
        RF1A_OM_IDLE);
      if (err != SUCCESS){
        //DBG 4
        //This fails with an EBUSY
        cerror(LINK, "LINK.sleep: p.srb0 %x\r\n", err);
      }
      err = call Rf1aPhysical.sleep();
      if (err != SUCCESS){
        //DBG 5
        //This fails with an ERETRY
        cerror(LINK, "LINK.sleep: p.sleep %x\r\n", err);
      }
      call Msp430XV2ClockControl.stopMicroTimer();
      atomic state = S_SLEEP;
      if (localState == S_RX){
        doSignalRXDone();
      }
      return err;
    }
  }


  task void handleSendDone();
  bool readyForward(message_t* msg);
  error_t subsend(message_t* msg);

  task void startImmediately(){
    atomic{
      signal FastAlarm.fired();
    }
  }

  bool synchMiss = FALSE;
  bool retxMiss = FALSE;

  #if DL_LINK <= DL_ERROR && DL_GLOBAL <= DL_ERROR
  task void logRetxMiss(){
    cerror(LINK, "RMD\r\n");
  }
  task void logSynchMiss(){
    cerror(LINK, "SMD\r\n");
  }

  void doSignalRXDone(){
    if (synchMiss){
      post logSynchMiss();
    }
    if (retxMiss){
      post logRetxMiss();
    }
    signal CXLink.rxDone();
  }
  #else 
  void doSignalRXDone(){
    signal CXLink.rxDone();
  }
  #endif


  event void DelayedSend.sendReady(){
//    P1OUT |= BIT2;
    atomic {
      uint32_t now = call FastAlarm.getNow();
      if (aSfdCapture){
        if( SELF_SFD_SYNCH ||  !aSynched ){
          //first synch point: computed based on sfd capture (either RX
          //or TX)
          // if now-aSfdCapture > frameLen-sfdAdjust, then we missed
          // the deadline. 
          // We crank down the TX power to reduce the possibility of
          // this impacting the rest of the network while keeping the
          // logic flow intact.
          if (now - aSfdCapture > frameLen - sfdAdjust){
            call Rf1aPhysical.setPower(MIN_POWER);
            synchMiss = TRUE;
          }
          call FastAlarm.startAt(aSfdCapture,  
            frameLen - sfdAdjust);
          aSynched = TRUE;
        }else{
//          //every subsequent transmission: should be based on the
//          //  previous one.
          if (now - (call FastAlarm.getAlarm()) > frameLen){
            call Rf1aPhysical.setPower(MIN_POWER);
            retxMiss = TRUE;
          }
          call FastAlarm.startAt(call FastAlarm.getAlarm(),
            frameLen);
        }
      }else{
//        //N.B.: at this point, packet is already loaded into
//        // buffer, so we can't modify it. Need to either use
//        // fragmentation (+ROM) or suck it up and timestamp it above
//        // this layer, accepting something on the line of 10s of ms
//        // accuracy.
//        //cheap/easy timestamping. This introduces a bias, as the
//        //actual SFD comes roughly 0.5 ms after the strobe command is
//        //issued. By adding those ticks back in here, we get it a bit
//        //closer.
//        if (metadata(fwdMsg)->tsLoc != NULL){
//          *(metadata(fwdMsg)->tsLoc) = (call LocalTime.get() + TS_CORRECTION );
//        }
        //first transmission: ok to trigger alarm immediately
        post startImmediately();
      }
    }
  }

  async event void Rf1aPhysical.sendDone (int result) { 
//    P1OUT &= ~BIT1;
    atomic{
      sfdAdjust = TX_SFD_ADJUST;
      aTxResult = result;
    }

    #if DL_LINK <= DL_DEBUG && DL_GLOBAL <= DL_DEBUG
    if (crcIndex < CRC_HIST_LEN){
      crcHist[crcIndex] = call LastCRC.getNow();
      txHist[crcIndex] = TRUE;
      crcIndex++;
    }
    #endif
    post handleSendDone();
  }

  task void handleSendDone(){
    uint8_t localState;
    error_t error;
    atomic localState = state;
    atomic error = aTxResult;
    if (POWER_ADJUST && frameLen == FRAMELEN_FAST_SHORT){
      call Rf1aPhysical.setPower(MIN_POWER);
    }
    if (error != SUCCESS){
      cerror(LINK, "TXR %x\r\n", error);
//      //mark this transmission as having failed CRC so we stop
//      //forwarding it.
      //TODO: why is this commented? we should stop forwarding. Or at
      //  least, we should turn the power down so that we can keep
      //  timing going as-is
//      phy(rxMsg)->lqi &= ~0x80;
    }
    
    //apply the raw timestamp.
    if (metadata(fwdMsg)->timeFast == 0){
      atomic metadata(fwdMsg)->timeFast = aSfdCapture - sfdAdjust;
//        cdbg(SCHED, "TS %lu - %lu - (%lu * (%u - 1)) = %lu \r\n",
//          slowRef, slowTicks, 
//          frameLen, metadata(fwdMsg)->rxHopCount,
//          metadata(fwdMsg)->time32k);
    }

    if (localState == S_TX || localState == S_FWD){
      if (readyForward(fwdMsg)){
        cdbg(LINK, "LFWD\r\n");
        error = subsend(fwdMsg);
        if (error != SUCCESS){
          cerror(LINK, "SS1 %x\r\n", error);
        }
      } else {
        call FastAlarm.stop();
        cinfo(LINK, "LD %u %u %u %u\r\n",
          header(fwdMsg)->source,
          header(fwdMsg)->sn,
          header(fwdMsg)->ttl,
          header(fwdMsg)->hopCount);
        if (localState == S_TX){
          atomic {
            state = S_IDLE;
            call Msp430XV2ClockControl.stopMicroTimer();
            call Rf1aPhysical.resumeIdleMode(RF1A_OM_IDLE);
            call Rf1aPhysical.setReceiveBuffer(NULL, 0, TRUE,
              RF1A_OM_IDLE);
          }
          cinfo(LINK, "LTX %u %u %u %x\r\n",
            header(fwdMsg)->source, 
            header(fwdMsg)->sn,
            header(fwdMsg)->destination,
            metadata(fwdMsg)->retx); 
          logCRCs(
            header(fwdMsg)->source, 
            header(fwdMsg)->sn);
          applyTimestamp(fwdMsg);

          #if DL_LINK <= DL_DEBUG && DL_GLOBAL <= DL_DEBUG
          if (synchMiss){
            post logSynchMiss();
          }
          if (retxMiss){
            post logRetxMiss();
          }
          #endif

          signal Send.sendDone(fwdMsg, SUCCESS);
        } else {
          atomic {
            state = S_IDLE;
            call Msp430XV2ClockControl.stopMicroTimer();
            call Rf1aPhysical.resumeIdleMode(RF1A_OM_IDLE);
            call Rf1aPhysical.setReceiveBuffer(NULL, 0, TRUE,
              RF1A_OM_IDLE);
          }
          cinfo(LINK, "LRX %u %u %u %u %x\r\n",
            header(rxMsg)->source, 
            header(rxMsg)->sn,
            header(rxMsg)->destination, 
            metadata(rxMsg)->rxHopCount,
            metadata(rxMsg)->retx); 
          logCRCs(
            header(rxMsg)->source, 
            header(rxMsg)->sn);
          applyTimestamp(rxMsg);
          rxMsg = signal Receive.receive(rxMsg, 
            call Packet.getPayload(rxMsg, call Packet.payloadLength(rxMsg)), 
            call Packet.payloadLength(rxMsg));
          doSignalRXDone();
        }
      }
    }else{
      cwarn(LINK, "Link hsd unexpected state %x\r\n", localState);
    }
  }
  
  
  task void signalRXDone(){
    doSignalRXDone();
  }

  async event void FastAlarm.fired(){
    //n.b: using bitwise or rather than logical to prevent
    //  short-circuit evaluation
    if ((state == S_TX) | (state == S_FWD)){
//      P1OUT |= BIT1;
      call DelayedSend.startSend();
//      P1OUT &= ~BIT2;
    } else if (state == S_RX){
      if (aCSDetected && !aExtended){
        aExtended = TRUE;
        call FastAlarm.start(CX_CS_TIMEOUT_EXTEND);
      } else {
//        P1OUT &= ~BIT1;
        call Rf1aPhysical.resumeIdleMode(RF1A_OM_IDLE);
        call Rf1aPhysical.setReceiveBuffer(NULL, 0, TRUE,
          RF1A_OM_IDLE);
        state = S_IDLE;
        post signalRXDone();
      }
    } else {
      cwarn(LINK, "Link fa.f unexpected state %x\r\n", state);
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
   *  Put the radio into RX mode (->FSTXON), and start wait timeout.
   *  Set up SFD capture/etc.
   */
  command error_t CXLink.rx(uint32_t timeout, bool allowForward){
    uint8_t localState;
    atomic localState = state;
    if (localState == S_IDLE || localState == S_SLEEP){
      error_t error;
      bool microStarted = FALSE;
      if (! call Msp430XV2ClockControl.isMicroTimerRunning()){
        microStarted = TRUE;
        call Msp430XV2ClockControl.startMicroTimer();
      }
      error = call Rf1aPhysical.setReceiveBuffer((uint8_t*)rxMsg, 
        TOSH_DATA_LENGTH + sizeof(message_header_t)+sizeof(message_footer_t), TRUE,
        RF1A_OM_FSTXON );
//      P1OUT |= BIT1;
      call Packet.clear(rxMsg);
      //mark as crc failed: should happen anyway, but just being safe
      //here.
      phy(rxMsg)->lqi &= ~0x80;
      call CXLinkPacket.setAllowRetx(rxMsg, allowForward);
  
      if (SUCCESS == error){
        atomic{
          call FastAlarm.start(timeout);
          call SynchCapture.captureRisingEdge();
          aSfdCapture = 0;
          aCSDetected = FALSE;
          aExtended = FALSE;
          aSynched = FALSE;
          synchMiss = FALSE;
          retxMiss = FALSE;
          origTimeout = timeout;
          state = S_RX;

          #if DL_LINK <= DL_DEBUG && DL_GLOBAL <= DL_DEBUG
          crcIndex = 0;
          crcFirstPassed = 0xFF;
          {
            uint8_t i;
            for (i=0; i< CRC_HIST_LEN; i++){
              txHist[i] = FALSE;
              crcHist[i] = 0;
            }
          }
          #endif
        }
      } else{
        if (microStarted){
          call Msp430XV2ClockControl.stopMicroTimer();
        }
      }
      return error;
    }else{
      return EBUSY;
    }
  }
  
  /**
   * Set up the radio to transmit the provided packet immediately.
   */
  command error_t Send.send(message_t* msg, uint8_t len){
    uint8_t localState;
    atomic localState = state;
    if (localState == S_TX || localState == S_FWD){
      cwarn(LINK, "LS.S: %x\r\n", localState);
      return localState == S_TX? EBUSY: ERETRY;
    } else {
      error_t error = SUCCESS;
      //setPayloadLength will set up the header and will set the
      //  md's length field to a "tight fit."
      //Due to life being awesome, packets that are < 64 bytes
      //(encoded) have lots of weird timing characteristics, while
      //packets that are >= 64 bytes all behave the same.
      //In order to handle this, we force packets to either be:
      // a. SHORT_PACKET bytes long
      // b. >= LONG_PACKET bytes long
      //CXLinkPacket.setLen does not disrupt the header, though it
      // will dictate how many bytes we actually send out over the
      // radio.
      //Incidentally, since apparently Packet.clear() is meant to just
      //  wipe out headers, there may be garbage left over in the
      //  payload area after the "real" payload. As long as that
      //  garbage gets forwarded consistently, we don't really care.
      call Packet.setPayloadLength(msg, len);
      if (call CXLinkPacket.len(msg) <= SHORT_PACKET){
        call CXLinkPacket.setLen(msg, SHORT_PACKET);
      }else if (call CXLinkPacket.len(msg) < LONG_PACKET){
        call CXLinkPacket.setLen(msg, LONG_PACKET); 
      }
      cdbg(LINK, "RP.S %u %u\r\n", call CXLinkPacket.len(msg),
        header(msg)->ttl);
      if (localState == S_RX){
        call FastAlarm.stop();
        error = call Rf1aPhysical.resumeIdleMode(RF1A_OM_IDLE);
        if (error != SUCCESS){
          cerror(LINK, "s.s.rim %x\r\n", error);
        }else {
          error = call Rf1aPhysical.setReceiveBuffer(NULL, 0, TRUE,
            RF1A_OM_IDLE);
        }
        if (error != SUCCESS){
          cerror(LINK, "s.s.srb0 %x\r\n", error);
        }else{
          localState = S_IDLE;
        }
        post signalRXDone();
      }

      if (error == SUCCESS){
        header(msg)->sn = sn++;
        header(msg)->source = call ActiveMessageAddress.amAddress();
        //initialize to 1 hop: adjacent nodes are 1 hop away.
        header(msg)->hopCount = 1;
        //initialize to 1: this makes timestamp computation uniform at
        //src/forwarder
        metadata(msg)->rxHopCount = 1;
        #if DL_LINK <= DL_DEBUG && DL_GLOBAL <= DL_DEBUG
        crcIndex = 0;
        crcFirstPassed = 0;
        #endif
        //set to crc-passed initially
        phy(msg)->lqi |= 0x80;

        call Rf1aPhysical.setPower(MAX_POWER);
        error = subsend(msg);
    
        if (error == SUCCESS){
          atomic{
            aSfdCapture = 0;
            aSynched = FALSE;
            fwdMsg = msg;
            state = S_TX;
            synchMiss = FALSE;
            retxMiss = FALSE;
          }
        }else{
          cerror(LINK, "SS2 %x\r\n", error);
          //Should be OK to just signal this error up and deal with it
          //at a higher layer.
        }
      }
      return error;
    }
  }
  
  error_t subsend(message_t* msg){
    if(call Resource.isOwner()){
      error_t error;
      if (! call Msp430XV2ClockControl.isMicroTimerRunning()){
        call Msp430XV2ClockControl.startMicroTimer();
      }
//      //This is debug code for faking multi-hop networks. N.B. you may
//      // need to set the offmode to IDLE rather than FSTXON
//      // everywhere that this ability is used. 
//      call Rf1aPhysical.setChannel(32* (header(msg)->hopCount));
      error = call Rf1aPhysical.startTransmission(FALSE, TRUE);
      if (error == SUCCESS) {
        rf1a_offmode_t om = (header(msg)->ttl)?RF1A_OM_FSTXON:RF1A_OM_IDLE;
        call SynchCapture.captureRisingEdge();
        error = call Rf1aPhysical.send((uint8_t*)msg, 
          call CXLinkPacket.len(msg), om);
        frameLen = (call CXLinkPacket.len(msg) == SHORT_PACKET) ?  FRAMELEN_FAST_SHORT : FRAMELEN_FAST_NORMAL;
      }else{
        cwarn(LINK, "rp.st %x\r\n", error);
      }
      return error;
    } else {
      return EOFF;
    }
  }

  /**
   * update header fields of packet and return whether or not
   * forwarding is complete.
   */
  bool readyForward(message_t* msg){
    if (call Rf1aPhysicalMetadata.crcPassed(phy(msg))){
      if(header(msg)->ttl){
        header(msg)->hopCount++;
        header(msg)->ttl--;
      }
      return (header(msg)->ttl > 0) && (metadata(msg)->retx);
    }else{
      cinfo(LINK, "CRCF\r\n");
      return FALSE;
    }
  }


  int rxResult;
  async event void Rf1aPhysical.receiveDone (uint8_t* buffer,
                                             unsigned int count,
                                             int result) {
//    P1OUT &= ~BIT1;
    sfdAdjust = (count-sizeof(cx_link_header_t) <= SHORT_PACKET)? RX_SFD_ADJUST_FAST : RX_SFD_ADJUST_NORMAL;
    rxLen = count;
    rxResult = result;

    #if DL_LINK <= DL_DEBUG && DL_GLOBAL <= DL_DEBUG
    if (crcIndex < CRC_HIST_LEN){
      crcHist[crcIndex] = call LastCRC.getNow();
      txHist[crcIndex] = FALSE;
      crcIndex++;
    }
    #endif
    post handleReception();
  } 


  /**
   * Deal with the aftermath of packet reception: record
   * metadata/timing information, prepare for forwarding if needed.
   */
  task void handleReception(){
    uint8_t localState;
    atomic{
      call CXLinkPacket.setLen(rxMsg, rxLen);
      metadata(rxMsg)->rxHopCount = header(rxMsg)->hopCount;
      metadata(rxMsg)->timeFast = aSfdCapture - sfdAdjust;
      localState = state;
      call Rf1aPhysicalMetadata.store(phy(rxMsg));
      //mark as failed CRC, ugh
      if (rxResult != SUCCESS){
        cwarn(LINK, "p.rxf %x\r\n", rxResult);
        phy(rxMsg)->lqi &= ~0x80;
      }

      #if DL_LINK <= DL_DEBUG && DL_GLOBAL <= DL_DEBUG
      if (call Rf1aPhysicalMetadata.crcPassed(phy(rxMsg)) && (crcIndex-1) < crcFirstPassed){
        crcFirstPassed = crcIndex-1;
      }
      #endif

    }

    if (localState == S_RX){
      if (readyForward(rxMsg) ){
        error_t error;
        atomic{
          state = S_FWD;
          fwdMsg = rxMsg;
        }
        call Rf1aPhysical.setPower(MAX_POWER);
        error = subsend(fwdMsg);
        if (error != SUCCESS){
          cerror(LINK, "SS0 %x\r\n", error);
        }
      }else{
        call FastAlarm.stop();
        atomic {
          state = S_IDLE;
          call Msp430XV2ClockControl.stopMicroTimer();
          call Rf1aPhysical.resumeIdleMode(RF1A_OM_IDLE);
          call Rf1aPhysical.setReceiveBuffer(NULL, 0, TRUE,
            RF1A_OM_IDLE);
        }
        if (call Rf1aPhysicalMetadata.crcPassed(phy(rxMsg))){
          cinfo(LINK, "LRX %u %u %u %u %x\r\n",
            header(rxMsg)->source, 
            header(rxMsg)->sn,
            header(rxMsg)->destination, 
            metadata(rxMsg)->rxHopCount,
            metadata(rxMsg)->retx); 
          logCRCs(
            header(rxMsg)->source, 
            header(rxMsg)->sn);
          applyTimestamp(rxMsg);
          rxMsg = signal Receive.receive(rxMsg, 
            call Packet.getPayload(rxMsg, call Packet.payloadLength(rxMsg)),
            call Packet.payloadLength(rxMsg));
          doSignalRXDone();
        }else{
          bool allowForward = (metadata(rxMsg))->retx;
          uint32_t rxRemaining = call FastAlarm.getAlarm() - call FastAlarm.getNow(); 
          //CRC failed, wipe it.
          call Packet.clear(rxMsg);
          //If there was still time left on the clock when we stopped
          //it, fire it up again.
          if (rxRemaining < origTimeout){
//            uint32_t lastTimeout = origTimeout;
            error_t error = call CXLink.rx(rxRemaining, 
              allowForward);
            if (error == SUCCESS){
//              printf("RR %lu < %lu\r\n",
//                rxRemaining, lastTimeout);
              //pass
            }else{
              doSignalRXDone();
            }
          }else{
            doSignalRXDone();
          }
        }
      }
    }else{ 
      //DBG 6
      //This gets signalled whie we're in state S_SLEEP.
      cwarn(LINK, "Link hr unexpected state %x\r\n", localState);
    }
  }


  command error_t CXLink.setChannel(uint8_t channel){
    uint8_t localState;
    atomic localState = state;
    if (localState == S_IDLE || localState == S_SLEEP){
      return call Rf1aPhysical.setChannel(channel);
    }else{
      return ERETRY;
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
      call Msp430XV2ClockControl.stopMicroTimer();
      signal SplitControl.startDone(call Rf1aPhysical.sleep());
    }else {
      cerror(LINK, "Link no mem @start\r\n");
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
      call Rf1aPhysical.sleep();
      post signalStopDone();
      call Pool.put(rxMsg);
      rxMsg = NULL;
      return call Resource.release();
    }
  }

  command void* Send.getPayload(message_t* msg, uint8_t len){
    return call Packet.getPayload(msg, len);
  }

  command uint8_t Send.maxPayloadLength(){
    return call Packet.maxPayloadLength();
  }

  command error_t Send.cancel(message_t* msg){
    return FAIL;
  }

  async event void Rf1aPhysical.frameStarted () { }
  async event void Rf1aPhysical.clearChannel () { }
  async event void Rf1aPhysical.carrierSense () { 
    aCSDetected = TRUE;
  }
  async event void Rf1aPhysical.released () { }
  
  async event void ActiveMessageAddress.changed(){}
  
}
