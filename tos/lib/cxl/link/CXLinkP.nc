
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
  uint32_t sn;

  int aTxResult;
  
  enum {
    CRC_HIST_LEN=11,
  };
  norace bool txHist[CRC_HIST_LEN];
  norace uint16_t crcHist[CRC_HIST_LEN];
  norace uint8_t crcIndex;
  norace uint8_t crcFirstPassed;

  void logCRCs(am_addr_t src, uint32_t psn){
    if (crcIndex){
      uint8_t i;
      for (i=crcFirstPassed ; i < crcIndex; i++ ){
        uint8_t k = crcIndex - i;
        cdbg(LINK, "CH %u %lu %u %x %x\r\n", src, psn, k, txHist[i], crcHist[i]);
      }
    }
  }

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

  cx_link_header_t* header(message_t* msg){
    return (call CXLinkPacket.getLinkHeader(msg));
  }

  cx_link_metadata_t* metadata(message_t* msg){
    return (call CXLinkPacket.getLinkMetadata(msg));
  }
  rf1a_metadata_t* phy(message_t* msg){
    return (call CXLinkPacket.getPhyMetadata(msg));
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
        signal CXLink.rxDone();
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

  event void DelayedSend.sendReady(){
    
    atomic {
      if (aSfdCapture){
//        if(!aSynched){
          //first synch point: computed based on sfd capture (either RX
          //or TX)
        call FastAlarm.startAt(aSfdCapture,  
          frameLen - sfdAdjust);
//        aSynched = TRUE;
//        }else{
//          //every subsequent transmission: should be based on the
//          //  previous one.
//          call FastAlarm.startAt(call FastAlarm.getAlarm(),
//            frameLen);
//        }
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
    atomic{
      sfdAdjust = TX_SFD_ADJUST;
      aTxResult = result;
    }
    if (crcIndex < CRC_HIST_LEN){
      crcHist[crcIndex] = call LastCRC.getNow();
      txHist[crcIndex] = TRUE;
      crcIndex++;
    }
    post handleSendDone();
  }

  task void handleSendDone(){
    uint8_t localState;
    error_t error;
    atomic localState = state;
    atomic error = aTxResult;
    if (error != SUCCESS){
      cwarn(LINK, "TXR %x\r\n", error);
//      //mark this transmission as having failed CRC so we stop
//      //forwarding it.
//      phy(rxMsg)->lqi &= ~0x80;
    }
    //TODO: if time32k is not set, set it based on last sfd capture.
    if (localState == S_TX || localState == S_FWD){
      if (readyForward(fwdMsg)){
        subsend(fwdMsg);
      } else {
        call FastAlarm.stop();
        cinfo(LINK, "LD %u %lu %u %u\r\n",
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
          cinfo(LINK, "LTX %u %lu %u %x\r\n",
            header(fwdMsg)->source, 
            header(fwdMsg)->sn,
            header(fwdMsg)->destination,
            metadata(fwdMsg)->retx); 
          logCRCs(
            header(fwdMsg)->source, 
            header(fwdMsg)->sn);
          signal Send.sendDone(fwdMsg, SUCCESS);
        } else {
          atomic {
            state = S_IDLE;
            call Msp430XV2ClockControl.stopMicroTimer();
            call Rf1aPhysical.resumeIdleMode(RF1A_OM_IDLE);
            call Rf1aPhysical.setReceiveBuffer(NULL, 0, TRUE,
              RF1A_OM_IDLE);
          }
          cinfo(LINK, "LRX %u %lu %u %u %x\r\n",
            header(rxMsg)->source, 
            header(rxMsg)->sn,
            header(rxMsg)->destination, 
            metadata(rxMsg)->rxHopCount,
            metadata(rxMsg)->retx); 
          logCRCs(
            header(rxMsg)->source, 
            header(rxMsg)->sn);

          rxMsg = signal Receive.receive(rxMsg, 
            call Packet.getPayload(rxMsg, call Packet.payloadLength(rxMsg)), 
            call Packet.payloadLength(rxMsg));
          signal CXLink.rxDone();
        }
      }
    }else{
      cwarn(LINK, "Link hsd unexpected state %x\r\n", localState);
    }
  }

  
  task void signalRXDone(){
    signal CXLink.rxDone();
  }

  async event void FastAlarm.fired(){
    P1OUT |= BIT2;
    //n.b: using bitwise or rather than logical to prevent
    //  short-circuit evaluation
    if ((state == S_TX) | (state == S_FWD)){
      call DelayedSend.startSend();
      P1OUT &= ~(BIT2);
    } else if (state == S_RX){
      if (aCSDetected && !aExtended){
        aExtended = TRUE;
        call FastAlarm.start(CX_CS_TIMEOUT_EXTEND);
      } else {
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
      //switch to data channel if not already on it
      error_t error = call Rf1aPhysical.setReceiveBuffer((uint8_t*)rxMsg, 
        TOSH_DATA_LENGTH + sizeof(message_header_t)+sizeof(message_footer_t), TRUE,
        RF1A_OM_IDLE );
//      error_t error = call Rf1aPhysical.setReceiveBuffer((uint8_t*)rxMsg, 
//        TOSH_DATA_LENGTH + sizeof(message_header_t)+sizeof(message_footer_t), TRUE,
//        RF1A_OM_FSTXON );
//      printf("rxbuf: %u\r\n", 
//        TOSH_DATA_LENGTH + sizeof(message_header_t));
      call Packet.clear(rxMsg);
      //mark as crc failed: should happen anyway, but just being safe
      //here.
      phy(rxMsg)->lqi &= ~0x80;
      call CXLinkPacket.setAllowRetx(rxMsg, allowForward);
  
      if (SUCCESS == error){
        if (! call Msp430XV2ClockControl.isMicroTimerRunning()){
          call Msp430XV2ClockControl.startMicroTimer();
        }
        atomic{
          call FastAlarm.start(timeout);
          call SynchCapture.captureRisingEdge();
          aSfdCapture = 0;
          aCSDetected = FALSE;
          aExtended = FALSE;
          aSynched = FALSE;
          state = S_RX;
          crcIndex = 0;
          crcFirstPassed = 0xFF;
          {
            uint8_t i;
            for (i=0; i< CRC_HIST_LEN; i++){
              txHist[i] = FALSE;
              crcHist[i] = 0;
            }
          }
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
        crcIndex = 0;
        //set to crc-passed initially
        phy(msg)->lqi |= 0x80;

        crcFirstPassed = 0;
        error = subsend(msg);
    
        if (error == SUCCESS){
          atomic{
            aSfdCapture = 0;
            aSynched = FALSE;
            fwdMsg = msg;
            state = S_TX;
          }
        }else{
          cwarn(LINK, "ss %x\r\n", error);
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
      //TODO: Debug: remove me!
      call Rf1aPhysical.setChannel(32* (header(msg)->hopCount));
      error = call Rf1aPhysical.startTransmission(FALSE, TRUE);
      if (error == SUCCESS) {
//        rf1a_offmode_t om = (header(msg)->ttl)?RF1A_OM_FSTXON:RF1A_OM_IDLE;
        rf1a_offmode_t om = RF1A_OM_IDLE;
        call SynchCapture.captureRisingEdge();
//        printf("ss %p %u\r\n", msg, call CXLinkPacket.len(msg));
        error = call Rf1aPhysical.send((uint8_t*)msg, 
          call CXLinkPacket.len(msg), om);
        if (error == SUCCESS){
          frameLen = (call CXLinkPacket.len(msg) == SHORT_PACKET) ?  FRAMELEN_FAST_SHORT : FRAMELEN_FAST_NORMAL;
        }
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
      cwarn(LINK, "CRCF\r\n");
      return FALSE;
    }
  }


  int rxResult;
  async event void Rf1aPhysical.receiveDone (uint8_t* buffer,
                                             unsigned int count,
                                             int result) {
    //TODO: if this does turn out to be length-dependent (still don't
    //see how that could be the case), then replace this with a lookup
    //into a table by count. This table might be annoyingly big, say
    //4*110 bytes.
    sfdAdjust = (count-sizeof(cx_link_header_t) <= SHORT_PACKET)? RX_SFD_ADJUST_FAST : RX_SFD_ADJUST_NORMAL;
    rxLen = count;
    rxResult = result;
    if (crcIndex < CRC_HIST_LEN){
      crcHist[crcIndex] = call LastCRC.getNow();
      txHist[crcIndex] = FALSE;
      crcIndex++;
    }
    post handleReception();
  } 

  uint32_t fastToSlow(uint32_t fastTicks){
    //OK w.r.t overflow as long as fastTicks is 22 bits or less (0.64 seconds)
    return (FRAMELEN_SLOW*fastTicks)/FRAMELEN_FAST_NORMAL;
  }

  /**
   * Deal with the aftermath of packet reception: record
   * metadata/timing information, prepare for forwarding if needed.
   */
  task void handleReception(){
    uint8_t localState;
    atomic{
      uint32_t fastRef1 = call FastAlarm.getNow();
      uint32_t slowRef = call LocalTime.get();
      uint32_t fastRef2 = call FastAlarm.getNow();
      uint32_t fastTicks = fastRef1 + ((fastRef2-fastRef1)/2) - aSfdCapture - sfdAdjust;
      uint32_t slowTicks = fastToSlow(fastTicks);
      
      call CXLinkPacket.setLen(rxMsg, rxLen);
      metadata(rxMsg)->rxHopCount = header(rxMsg)->hopCount;
      metadata(rxMsg)->time32k = slowRef 
        - slowTicks 
        - (FRAMELEN_SLOW*(metadata(rxMsg)->rxHopCount-1));
      localState = state;
      call Rf1aPhysicalMetadata.store(phy(rxMsg));
      //mark as failed CRC, ugh
      if (rxResult != SUCCESS){
        cwarn(LINK, "p.rxf %x\r\n", rxResult);
        phy(rxMsg)->lqi &= ~0x80;
      }
      if (call Rf1aPhysicalMetadata.crcPassed(phy(rxMsg)) && (crcIndex-1) < crcFirstPassed){
        crcFirstPassed = crcIndex-1;
      }

//      sfdAdjust += (SFD_ADJUST_HOP * (header(rxMsg)->hopCount -1));
    }
//    printf("hr %p %u %u %u\r\n", rxMsg, call CXLinkPacket.len(rxMsg),
//      rxLen, rxResult);
    if (localState == S_RX){
      if (readyForward(rxMsg) ){
        atomic{
          state = S_FWD;
          fwdMsg = rxMsg;
        }
        subsend(fwdMsg);
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
          cinfo(LINK, "LRX %u %lu %u %u %x\r\n",
            header(rxMsg)->source, 
            header(rxMsg)->sn,
            header(rxMsg)->destination, 
            metadata(rxMsg)->rxHopCount,
            metadata(rxMsg)->retx); 
          logCRCs(
            header(rxMsg)->source, 
            header(rxMsg)->sn);
          rxMsg = signal Receive.receive(rxMsg, 
            call Packet.getPayload(rxMsg, call Packet.payloadLength(rxMsg)),
            call Packet.payloadLength(rxMsg));
        }else{
          //CRC failed, wipe it.
          call Packet.clear(rxMsg);
        }
        signal CXLink.rxDone();
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
