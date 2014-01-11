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


 #include "CXLink.h"
 #include "CXLinkDebug.h"
 #include "CXScheduleDebug.h"

module CXLinkP {
  provides interface SplitControl;
  uses interface SplitControl as SubSplitControl;

  uses interface Rf1aPhysical;
  uses interface DelayedSend;
  uses interface Rf1aStatus;

  uses interface GpioCapture as SynchCapture;
  uses interface Msp430XV2ClockControl;
  uses interface Alarm<TMicro, uint32_t> as FastAlarm;
  uses interface LocalTime<T32khz>; 
  uses interface LocalTime<TMilli> as LocalTimeMilli; 
//  uses interface Timer<T32khz> as CompletionTimer;

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
  bool started = FALSE;
  bool sleepPending = FALSE;
  uint8_t txLeft;
  
  #if DL_LINK_TIMING <= DL_WARN && DL_GLOBAL <= DL_WARN
  uint32_t dfLog;
  bool dfMissed;
  uint32_t rxStart;
  #endif
  #if DL_STATS_RADIO <= DL_INFO && DL_GLOBAL <= DL_INFO
  uint32_t aFeCapture;
  cx_link_stats_t lastStats;
  cx_link_stats_t curStats;
  #endif
  
  bool reCapture;

  typedef enum link_status_e {
    R_OFF = 0,
    R_SLEEP = 1,
    R_IDLE = 2, 
    R_FSTXON = 3,
    R_TX = 4,
    R_RX = 5,
    R_NUMSTATES = 6
  } link_status_e;

  #if DL_STATS_RADIO <= DL_INFO && DL_GLOBAL <= DL_INFO
  link_status_e curState = R_OFF;
  uint32_t lastChange;


  void radioStateChangeAtTime(uint8_t newState, uint32_t changeTime){
    atomic{
      uint32_t elapsed = changeTime - lastChange;
      cdbg(STATS, "sc %x %x %lu %lu\r\n", 
        curState, newState,
        lastChange, changeTime);
      switch(curState){
        case R_OFF:
          curStats.off += elapsed;
          break;
        case R_SLEEP:
          curStats.sleep += elapsed;
          break;
        case R_IDLE:
          curStats.idle += elapsed;
          break;
        case R_RX:
          curStats.rx += elapsed;
          break;
        case R_TX:
          curStats.tx += elapsed;
          break;
        case R_FSTXON:
          curStats.fstxon += elapsed;
          break;
        default:
          cwarn(STATS, "? %x\r\n", curState);
          break;
      }
      curState = newState;
      lastChange = changeTime;
    }
  }

  void radioStateChange(uint8_t newState){
    radioStateChangeAtTime(newState, call FastAlarm.getNow());
  }

  void stopMicro(){ }
  void startMicro(){ 
    call Msp430XV2ClockControl.startMicroTimer();
  }
  #else
  void radioStateChange(uint8_t newState){}
  void radioStateChangeAtTime(uint8_t newState, uint32_t t){}
  void stopMicro(){
    call Msp430XV2ClockControl.stopMicroTimer();
  }
  void startMicro(){
    call Msp430XV2ClockControl.startMicroTimer();
  }
  #endif

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

    S_TX_END=4,
    S_FWD_END=5,

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

  uint32_t slowToFast(uint32_t slowTicks){
    //OK w.r.t overflow as long as slowTicks is less than 21145 (0.64
    // seconds)
    return (slowTicks * FRAMELEN_FAST_NORMAL)/FRAMELEN_SLOW;
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
    atomic cerror(LINK, "LSD %x %p %p %x\r\n",
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

    if (sleepPending){
      return EALREADY;
    }
    if (localState == S_TX || localState == S_FWD){
      sleepPending = TRUE;
      return SUCCESS;
    }else if (localState == S_RX){
      sleepPending = TRUE;
      return SUCCESS;
    }else {
      error_t err = call Rf1aPhysical.resumeIdleMode(RF1A_OM_IDLE);
      sleepPending = FALSE;
      radioStateChange(R_IDLE);
      if (err != SUCCESS){
        cerror(LINK, "L.s0 %x\r\n", err);
      }
      err = call Rf1aPhysical.setReceiveBuffer(NULL, 0, TRUE,
        RF1A_OM_IDLE);
      if (err != SUCCESS){
        //DBG 4
        //This fails with an EBUSY
        cerror(LINK, "L.s1 %x %x\r\n", err, call Rf1aStatus.get());
      }
      err = call Rf1aPhysical.sleep();
      radioStateChange(R_SLEEP);
      if (err != SUCCESS){
        //DBG 5
        //This fails with an ERETRY
        cerror(LINK, "L.s2: %x %x\r\n", err, call Rf1aStatus.get());
      }
      stopMicro();
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
    cwarn(LINK, "RMD\r\n");
  }
  task void logSynchMiss(){
    cwarn(LINK, "SMD\r\n");
  }
  #endif

  void doSignalRXDone(){
    #if DL_LINK <= DL_ERROR && DL_GLOBAL <= DL_ERROR
    if (synchMiss){
      post logSynchMiss();
    }
    if (retxMiss){
      post logRetxMiss();
    }
    #endif
    if (sleepPending){
      call CXLink.sleep();
    }
//    P1OUT &= ~BIT1;
    signal CXLink.rxDone();
  }


  event void DelayedSend.sendReady(){
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
        //first transmission: check for the presence of a txTime
        // in metadata. If it's there, then translate the desired 32k
        // time into the fast time scale and set the initial tx
        // accordingly.
        if (metadata(fwdMsg)->txTime != 0){
          uint32_t fb0 = call FastAlarm.getNow();
          uint32_t sb = call LocalTime.get();
          uint32_t fb1 = call FastAlarm.getNow();

          uint32_t ds = metadata(fwdMsg)->txTime - sb;
          uint32_t df = 0;

          //verify overflow-safety (also implicitly checks for cases
          //where txTime < current time)
          if (ds < 21145UL){
            df = slowToFast(ds);
            #if DL_LINK_TIMING <= DL_WARN && DL_GLOBAL <= DL_WARN
            dfLog = df;
            #endif
            call FastAlarm.startAt(fb0 + (fb1-fb0)/2, df);
          } else{
            //TODO: if we missed the deadline, then it's very likely
            //that no nodes will be around to receive it.  Would be
            //better to cancel the transmission and signal ERETRY up.
            //Or, at least signal completion with ERETRY so that we
            //attempt to send this again (am queuing layer will do
            //this automatically, though it will also stop
            //transmitting for the remainder of this slot.)
            #if DL_LINK_TIMING <= DL_WARN && DL_GLOBAL <= DL_WARN
            dfMissed = TRUE;
            dfLog = slowToFast( sb - metadata(fwdMsg)->txTime);
            #endif
            post startImmediately();
          }
        }else{
          post startImmediately();
        }
      }
    }
  }

  async event void Rf1aPhysical.sendDone (int result) { 
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
    #if DL_STATS_RADIO <= DL_INFO && DL_GLOBAL <= DL_INFO
    atomic radioStateChangeAtTime(R_TX, aSfdCapture - sfdAdjust);
    atomic radioStateChangeAtTime(call Rf1aStatus.get() == RF1A_S_FSTXON?  R_FSTXON : R_IDLE, aFeCapture);
    #endif
    //N.B. at this point, you could check packet length and TTL, and
    //either immediately post this task or set a milli timer to kick
    //it off prior to the next fastalarm.
    post handleSendDone();
  }

  task void completeOperation(){
    uint8_t localState;
    atomic localState = state;
    stopMicro();
    if(localState == S_TX_END){
      atomic state = S_IDLE;
      signal Send.sendDone(fwdMsg, SUCCESS);
    }else if (localState == S_FWD_END){
      atomic state = S_IDLE;
      rxMsg = signal Receive.receive(rxMsg, 
        call Packet.getPayload(rxMsg, call Packet.payloadLength(rxMsg)), 
        call Packet.payloadLength(rxMsg));
      doSignalRXDone();
    }
  }
   
  void setCompletionTimer(message_t* msg){
    if (! metadata(msg)->retx){
      post startImmediately();
    }else{
      if (! call Msp430XV2ClockControl.isMicroTimerRunning()){
        startMicro();
      }
      if (call CXLinkPacket.len(msg) == SHORT_PACKET){
        call FastAlarm.start(FRAMELEN_FAST_SHORT*header(msg)->ttl);
      }else{
        call FastAlarm.start(FRAMELEN_FAST_NORMAL*header(msg)->ttl);
      }
    }
  }

  task void handleSendDone(){
    uint8_t localState;
    error_t error;
    atomic localState = state;
    atomic error = aTxResult;
    if (POWER_ADJUST && frameLen == FRAMELEN_FAST_SHORT){
      call Rf1aPhysical.setPower(MIN_POWER);
    }
    if (txLeft){
      txLeft --;
    }
//    printf("hsd %u\r\n", txLeft);
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
          //TODO: a failure here will leave the link layer state
          //machine stuck. set up for completion.
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
            state = S_TX_END;
            stopMicro();
            call Rf1aPhysical.resumeIdleMode(RF1A_OM_IDLE);
            radioStateChange(R_IDLE);
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
          #if DL_LINK_TIMING <= DL_WARN && DL_GLOBAL <= DL_WARN
          if (metadata(fwdMsg)->txTime){
            if (dfMissed){
              cwarn(LINK_TIMING, "TTM\r\n");
              cinfo(LINK_TIMING, "T -%lu\r\n", dfLog);
            }else{
              cinfo(LINK_TIMING, "T %lu\r\n", dfLog);
            }
          }
          #endif
          if (sleepPending){
            call CXLink.sleep();
          }
          setCompletionTimer(fwdMsg);
        } else {
          atomic {
            state = S_FWD_END;
            stopMicro();
            call Rf1aPhysical.resumeIdleMode(RF1A_OM_IDLE);
            radioStateChange(R_IDLE);
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
          #if DL_LINK_TIMING <= DL_INFO && DL_GLOBAL <= DL_INFO
          if (metadata(rxMsg)->retx){
            cinfo(LINK_TIMING, "R %lu\r\n", 
              metadata(rxMsg)->timeFast - rxStart);
          }
          #endif
          setCompletionTimer(rxMsg);
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
      
      call DelayedSend.startSend();
    } else if (state == S_RX){
      if (aCSDetected && !aExtended){
        aExtended = TRUE;
        call FastAlarm.start(CX_CS_TIMEOUT_EXTEND);
      } else {
        call Rf1aPhysical.resumeIdleMode(RF1A_OM_IDLE);
        #if DL_STATS_RADIO <= DL_INFO && DL_GLOBAL <= DL_INFO
        aFeCapture = call FastAlarm.getNow();
        radioStateChange(R_IDLE);
        #endif
        call Rf1aPhysical.setReceiveBuffer(NULL, 0, TRUE,
          RF1A_OM_IDLE);
        state = S_IDLE;
        post signalRXDone();
      }
    } else if (state == S_TX_END || state == S_FWD_END){
      post completeOperation();
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
    if (reCapture){
      //expand to 32 bits
      aSfdCapture = (ft & 0xffff0000) | time;
      #if DL_STATS_RADIO <= DL_INFO && DL_GLOBAL <= DL_INFO
      reCapture = FALSE;
      call SynchCapture.captureFallingEdge();
      #endif
    }else{
      call SynchCapture.disable();
      #if DL_STATS_RADIO <= DL_INFO && DL_GLOBAL <= DL_INFO
      aFeCapture = (ft & 0xffff0000) | time;
      #endif
    }
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
        startMicro();
      }
      radioStateChange(R_RX);
      //TODO: this should set RF1A_OM based on allowForward, right?
      error = call Rf1aPhysical.setReceiveBuffer((uint8_t*)rxMsg, 
        TOSH_DATA_LENGTH + sizeof(message_header_t)+sizeof(message_footer_t), TRUE,
        RF1A_OM_FSTXON );
//      P1OUT |= BIT1;
      #if DL_LINK_TIMING <= DL_INFO && DL_GLOBAL <= DL_WARN
      rxStart = call FastAlarm.getNow();
      #endif
      call Packet.clear(rxMsg);
      //mark as crc failed: should happen anyway, but just being safe
      //here.
      phy(rxMsg)->lqi &= ~0x80;
      call CXLinkPacket.setAllowRetx(rxMsg, allowForward);
  
      if (SUCCESS == error){
        atomic{
          call FastAlarm.start(timeout);
          atomic{
            reCapture = TRUE;
            call SynchCapture.captureRisingEdge();
          }
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
          stopMicro();
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

    #if DL_LINK_TIMING <= DL_WARN && DL_GLOBAL <= DL_WARN
    dfLog = 0;
    dfMissed = FALSE;
    #endif
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
        radioStateChange(R_IDLE);
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
            txLeft = (call CXLinkPacket.len(msg) == SHORT_PACKET)?  MAX_TX_SHORT : MAX_TX_LONG;

            txLeft = (txLeft > header(msg)->ttl)? header(msg)->ttl: txLeft;
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
    if(started){
      error_t error;
      if (! call Msp430XV2ClockControl.isMicroTimerRunning()){
        startMicro();
      }
//      //This is debug code for faking multi-hop networks. N.B. you may
//      // need to set the offmode to IDLE rather than FSTXON
//      // everywhere that this ability is used. 
//      call Rf1aPhysical.setChannel(32* (header(msg)->hopCount));
      radioStateChange(R_FSTXON);
      error = call Rf1aPhysical.startTransmission(FALSE, TRUE);
      if (error == SUCCESS) {
        rf1a_offmode_t om = (header(msg)->ttl)?RF1A_OM_FSTXON:RF1A_OM_IDLE;
        atomic {
          reCapture = TRUE;
          call SynchCapture.captureRisingEdge();
        }
        error = call Rf1aPhysical.send((uint8_t*)msg, 
          call CXLinkPacket.len(msg), om);
        frameLen = (call CXLinkPacket.len(msg) == SHORT_PACKET) ?  FRAMELEN_FAST_SHORT : FRAMELEN_FAST_NORMAL;
      }else{
        cerror(LINK, "rp.st %x\r\n", error);
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
      return (txLeft > 0) && (header(msg)->ttl > 0) && (metadata(msg)->retx);
    }else{
      cinfo(LINK, "CRCF\r\n");
      return FALSE;
    }
  }


  int rxResult;
  async event void Rf1aPhysical.receiveDone (uint8_t* buffer,
                                             unsigned int count,
                                             int result) {
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
    #if DL_STATS_RADIO <= DL_INFO && DL_GLOBAL <= DL_INFO
    atomic radioStateChangeAtTime(call Rf1aStatus.get() == RF1A_S_FSTXON?  R_FSTXON : R_IDLE, aFeCapture);
    #endif
    //N.B. at this point, you could check packet length and TTL, and
    //either immediately post this task or set a milli timer to kick
    //it off prior to the next fastalarm.
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
        cerror(LINK, "p.rxf %x\r\n", rxResult);
        phy(rxMsg)->lqi &= ~0x80;
      }

      #if DL_LINK <= DL_DEBUG && DL_GLOBAL <= DL_DEBUG
      if (call Rf1aPhysicalMetadata.crcPassed(phy(rxMsg)) && (crcIndex-1) < crcFirstPassed){
        crcFirstPassed = crcIndex-1;
      }
      #endif

    }

    if (localState == S_RX){
      txLeft = MAX_TX_SHORT;
      if (readyForward(rxMsg) ){
        error_t error;
        txLeft = (call CXLinkPacket.len(rxMsg) == SHORT_PACKET)?  MAX_TX_SHORT : MAX_TX_LONG;

        txLeft = (txLeft > header(rxMsg)->ttl)? header(rxMsg)->ttl: txLeft;
        atomic{
          state = S_FWD;
          fwdMsg = rxMsg;
        }
        call Rf1aPhysical.setPower(MAX_POWER);
        error = subsend(fwdMsg);
        if (error != SUCCESS){
          //state flow expects to get a sendDone from this call.
          //if subsend fails, it won't. so, hook it up.
          cerror(LINK, "SS0 %x\r\n", error);
          atomic {
            state = S_FWD_END;
            stopMicro();
            call Rf1aPhysical.resumeIdleMode(RF1A_OM_IDLE);
            radioStateChange(R_IDLE);
            call Rf1aPhysical.setReceiveBuffer(NULL, 0, TRUE,
              RF1A_OM_IDLE);
          }
          cinfo(LINK, "LRX %u %u %u %u %x\r\n",
            header(fwdMsg)->source, 
            header(fwdMsg)->sn,
            header(fwdMsg)->destination, 
            metadata(fwdMsg)->rxHopCount,
            metadata(fwdMsg)->retx); 
          logCRCs(
            header(fwdMsg)->source, 
            header(fwdMsg)->sn);
          applyTimestamp(fwdMsg);
          #if DL_LINK_TIMING <= DL_INFO && DL_GLOBAL <= DL_INFO
          if (metadata(fwdMsg)->retx){
            cinfo(LINK_TIMING, "R %lu\r\n", 
              metadata(fwdMsg)->timeFast - rxStart);
          }
          #endif
          setCompletionTimer(fwdMsg);
        }
      }else{
        call FastAlarm.stop();
        atomic {
          state = S_IDLE;
          stopMicro();
          call Rf1aPhysical.resumeIdleMode(RF1A_OM_IDLE);
          radioStateChange(R_IDLE);
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
          #if DL_LINK_TIMING <= DL_INFO && DL_GLOBAL <= DL_INFO
          if (metadata(rxMsg)->retx){
            cinfo(LINK_TIMING, "R %lu\r\n", 
              metadata(rxMsg)->timeFast - rxStart);
          }
          #endif
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
    if (started){
      return EALREADY;
    }else{
      return call SubSplitControl.start();
    }
  }

  event void SubSplitControl.startDone(error_t error){
    if (error == SUCCESS){
      rxMsg = call Pool.get();
      started = TRUE;
      if (rxMsg){
        stopMicro();
        signal SplitControl.startDone(call Rf1aPhysical.sleep());
        radioStateChange(R_SLEEP);
      }else {
        cerror(LINK, "LNM\r\n");
        signal SplitControl.startDone(ENOMEM);
      }
    }else{
      signal SplitControl.startDone(error);
    }
  }

  command error_t SplitControl.stop(){
    if (! started){
      return EALREADY;
    }else{
      call Rf1aPhysical.sleep();
      radioStateChange(R_OFF);
      call Pool.put(rxMsg);
      rxMsg = NULL;
      return call SubSplitControl.stop();
    }
  }

  event void SubSplitControl.stopDone(error_t error){
    if (error == SUCCESS){
      started = FALSE;
    }
    signal SplitControl.stopDone(error);
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

  command cx_link_stats_t CXLink.getStats(){
    cx_link_stats_t ret;
    #if DL_STATS_RADIO <= DL_INFO && DL_GLOBAL <= DL_INFO
    atomic{
      radioStateChange(curState);
      curStats.total = call FastAlarm.getNow();
      ret.total = curStats.total - lastStats.total;
      ret.off = curStats.off - lastStats.off;
      ret.idle = curStats.idle - lastStats.idle;
      ret.sleep = curStats.sleep - lastStats.sleep;
      ret.rx = curStats.rx - lastStats.rx;
      ret.tx = curStats.tx - lastStats.tx;
      ret.fstxon = curStats.fstxon - lastStats.fstxon;
      lastStats = curStats;
    }
    #endif
    return ret;
  }
  
}
