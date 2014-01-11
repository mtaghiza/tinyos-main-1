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


 #include "CXMac.h"
 #include "CXLppDebug.h"
 #include "multiNetwork.h"
module CXWakeupP {
  provides interface LppControl;

  provides interface SplitControl;
  provides interface Send;
  provides interface Receive;

  uses interface SplitControl as SubSplitControl;
  uses interface Send as SubSend;
  uses interface Receive as SubReceive;

  uses interface Pool<message_t>;

  provides interface CXLink;

  uses interface CXLink as SubCXLink;
  uses interface CXLinkPacket;
  uses interface CXMacPacket;
  //This packet interface goes to body of mac packet
  uses interface Packet;
  //and this goes to body of link packet
  uses interface Packet as LinkPacket;

  uses interface Timer<TMilli> as ProbeTimer;
  uses interface Random;

  uses interface Timer<TMilli> as TimeoutCheck;

  uses interface StateDump;

  provides interface LppProbeSniffer;

  uses interface Get<probe_schedule_t*>;
  uses interface Get<uint16_t> as RebootCounter;
} implementation {

  uint8_t activeNS;
  uint8_t curChannel;
  uint8_t probeCount;
  uint8_t scheduleIndex;
  
  enum {
    S_OFF = 0,
    S_IDLE = 1,
    S_CHECK = 2,
    S_AWAKE = 3
  };

  bool sending = FALSE;

  uint8_t state = S_OFF;
  //used to disambiguate handling of first rxDone at wakeup
  bool firstWakeup = FALSE;
  //used to disambiguate cases where the upper layer has forced this
  //layer to rx despite being in S_IDLE: this is used, for instance,
  //to sniff probes.
  bool forceRx = FALSE;
  uint32_t probeInterval = LPP_DEFAULT_PROBE_INTERVAL;
  message_t* probe;

  //used to handle the situation where a wakeup is requested while
  // we're probing/checking for wakeup.
  bool manualWakeupPending = FALSE;
  uint8_t manualWakeupNS;
  
  probe_schedule_t* sched;
  void refreshSched(){
    sched = call Get.get();
    probeInterval = sched->probeInterval;
  }

  uint8_t activeChannel(){
    return sched->channel[activeNS];
  }

  error_t setChannel(uint8_t channel){
    error_t error = SUCCESS;
    if (curChannel != channel){
      error = call SubCXLink.setChannel(channel);
      if (error == SUCCESS){
        curChannel = channel;
      }
    }
    return error;
  }

  #ifndef LPP_RAND_RANGE_EXP
  #define LPP_RAND_RANGE_EXP 8
  #endif

  #define LPP_RAND_RANGE (1 << LPP_RAND_RANGE_EXP)

  #define LPP_RAND_MASK (LPP_RAND_RANGE - 1)
  #define LPP_RAND_OFFSET (LPP_RAND_RANGE >> 1)

  uint32_t randomize(uint32_t mean){
    return (mean - LPP_RAND_OFFSET) + ((call Random.rand32()) & LPP_RAND_MASK ) ;
  }

  uint8_t nextProbe(uint8_t startIndex){
    #if CX_BASESTATION  == 1
    return startIndex;
    #elif CX_ROUTER == 1
    if (startIndex == NS_SUBNETWORK){
      return startIndex+1;
    }else{
      return startIndex;
    }
    #else
    if (startIndex == NS_ROUTER){
      return startIndex +1;
    }else{
      return startIndex;
    }
    #endif
//    uint8_t i;
//    for (i = startIndex; i < NUM_SEGMENTS; i++){
//      if (sched->maxDepth[i]){
//        break;
//      }
////      uint8_t invFreq;
////      invFreq = sched -> invFrequency[i];
////      if (invFreq && (probeCount % invFreq) == 0){
////        cdbg(LPP, "match %u\r\n", i);
////        break;
////      }
//    }
//    return i;
  }

  task void sendProbe(){
    error_t error;
    cx_lpp_probe_t* pl = call Packet.getPayload(probe,
      sizeof(cx_lpp_probe_t));
    activeNS = scheduleIndex;
    cdbg(LPP, "probe to %u @ %u\r\n", activeNS, probeCount);
    call Packet.clear(probe);
    call CXMacPacket.setMacType(probe, CXM_PROBE);
    (call CXLinkPacket.getLinkHeader(probe))->ttl = 2;
    (call CXLinkPacket.getLinkHeader(probe))->destination =
      AM_BROADCAST_ADDR;
    call CXLinkPacket.setAllowRetx(probe, FALSE);
    call Packet.setPayloadLength(probe, sizeof(cx_lpp_probe_t));
    pl -> rc = call RebootCounter.get();
    pl -> tMilli = call ProbeTimer.getNow();
    setChannel(activeChannel());
    error = call SubSend.send(probe, 
      call LinkPacket.payloadLength(probe));
    if ((call CXLinkPacket.getSn(probe) % PROBE_LOG_INTERVAL) == 1){
      cinfo(LPP_PROBE, "SP %u\r\n", call CXLinkPacket.getSn(probe));
    }
    cdbg(LPP, "MS p\r\n");
    if (SUCCESS != error){
      cerror(LPP, "pt.f ss %x\r\n", error);
      call Pool.put(probe);
      probe = NULL;
      state = S_IDLE;
      call ProbeTimer.startOneShot(randomize(probeInterval));
    }else{
      sending = TRUE;
      call TimeoutCheck.startOneShot(FRAMELEN_SLOW*2*2);
    }
  }

  event void ProbeTimer.fired(){
    #if DL_PROBE_STATS <= DL_INFO && DL_GLOBAL <= DL_DEBUG
    {
      cx_link_stats_t stats = call CXLink.getStats();
      cinfo(PROBE_STATS, "PS t %lu o %lu i %lu s %lu r %lu t %lu f %lu\r\n",
        stats.total,
        stats.off,
        stats.idle,
        stats.sleep,
        stats.rx,
        stats.tx,
        stats.fstxon ); 
    }
    #endif
    if (state == S_IDLE){
      if (forceRx){
        //in the middle of a sniff: try probing again later.
        call ProbeTimer.startOneShot(randomize(probeInterval));
      } else {
        probeCount++;
        scheduleIndex = 0;
        refreshSched();
        state = S_CHECK;
        probe = call Pool.get();
        if (probe){
          scheduleIndex = nextProbe(scheduleIndex);
          if (scheduleIndex < NUM_SEGMENTS){
            post sendProbe();
          }else {
            //no probes this round
            call Pool.put(probe);
            probe = NULL;
            call ProbeTimer.startOneShot(randomize(probeInterval));
            state = S_IDLE;
          }
        }else{
          cerror(LPP, "No probe left\r\n");
        }
      }
    }
  }

  event void SubSend.sendDone(message_t* msg, error_t error){
    call TimeoutCheck.stop();
    sending = FALSE;
    cdbg(LPP, "MS SD\r\n");
    if (error != SUCCESS){
      cwarn(LPP, "LPP ss.sd %x\r\n", error);
    }
    cinfo(LPP, "MTX %x %u %u %u %x\r\n",
      error,
      (call CXLinkPacket.getLinkHeader(msg))->source,
      (call CXLinkPacket.getLinkHeader(msg))->sn,
      (call CXLinkPacket.getLinkHeader(msg))->destination,
      call CXMacPacket.getMacType(msg));

    if (state == S_CHECK){
      if (msg == probe){
        //immediately after probe is sent, listen for a short period
        //of time.
        error_t err = call SubCXLink.rx(CHECK_TIMEOUT, FALSE);
        if (err == SUCCESS){
          call TimeoutCheck.startOneShot(CHECK_TIMEOUT_SLOW);
        } else {
          cerror(LPP, "LPP ss.sd ack rx %x\r\n", err);
        }

      }else{
        cwarn(LPP, "LPP ss.sd: check, but sent non-probe %p != %p\r\n", msg, probe);
        call Pool.put(probe);
        probe = NULL;
        signal Send.sendDone(msg, error);
      }
    }else{
      signal Send.sendDone(msg, error);
    }
  }
  

  event void SubCXLink.rxDone(){
    call TimeoutCheck.stop();

    //Still in S_CHECK? we didn't hear our probe come back. 
    //See if there are more probes to be sent right now, otherwise go
    //back to sleep.
    if (state == S_CHECK){
      cdbg(LPP, "rxd %u\r\n", scheduleIndex);
      scheduleIndex++;
      scheduleIndex = nextProbe(scheduleIndex);

      if (scheduleIndex < NUM_SEGMENTS){
        cdbg(LPP, "post %u\r\n", scheduleIndex);
        post sendProbe();
      }else{
        error_t error = call SubCXLink.sleep();
        cdbg(LPP, "done %u\r\n", scheduleIndex);
        if (error != SUCCESS){
          cerror(LPP, "LPP rxd s %x\r\n", error);
        }
        call Pool.put(probe);
        probe = NULL;
        state = S_IDLE;

        //if wakeup was requested while we were probing, 
        // and we are fixing to sleep, trigger the manual wakeup now.
        if (manualWakeupPending){
          manualWakeupPending = FALSE;
          call LppControl.wakeup(manualWakeupNS);
        }else{
          call ProbeTimer.startOneShot(randomize(probeInterval));
        }
      }
    } else if (state == S_AWAKE){
      if (firstWakeup){
        firstWakeup = FALSE;
      }else{
        signal CXLink.rxDone();
      }
    }else if (forceRx){
      //through sniffin'
      forceRx = FALSE;
      //any more meaningful error code?
      signal LppProbeSniffer.sniffDone(SUCCESS);
    } else {
      cerror(LPP, "URXD %x\r\n", state);
      //if we let upper layer request RX without doing a real wakeup
      //(e.g. to sniff for traffic), then this can/should happen.
    }
  }


  command error_t CXLink.rx(uint32_t timeout, bool retx){
    if (state == S_OFF){
      return EOFF;
    } else if (state == S_IDLE){
      return EOFF;
    } else if (state == S_CHECK){
      return ERETRY;
    }else if (state == S_AWAKE){
      setChannel(activeChannel());
      return call SubCXLink.rx(timeout, retx);
    }else{
      cerror(LPP, "LPPUS %x\r\n", state); 
      return FAIL;
    }
  }
  
  uint32_t milliToFast(uint32_t milli){
    return 32UL*((milli*FRAMELEN_FAST_NORMAL)/FRAMELEN_SLOW);
  }

  command error_t LppProbeSniffer.sniff(uint8_t ns){
    if (state == S_IDLE){
      uint32_t probeIntervalFast;
      error_t error;
      uint32_t probeIntervalMilli = probeInterval;
      activeNS = ns;
      setChannel(activeChannel());
//      probeIntervalMilli = (sched->invFrequency[ns]*probeInterval);
      probeIntervalFast = milliToFast(probeIntervalMilli);
      if (probeIntervalFast == 0){
        return EINVAL;
      }else{
        error = call SubCXLink.rx(probeIntervalFast, FALSE);
        if (SUCCESS == error){
          forceRx = TRUE;
        }
        return error;
      }
    }else {
      return ERETRY;
    }
  }

  am_addr_t lastSrc = AM_BROADCAST_ADDR;
  uint16_t lastSn;

  event message_t* SubReceive.receive(message_t* msg, void* pl, uint8_t len){
    cinfo(LPP, "MRX %u %u %u %x\r\n",
      (call CXLinkPacket.getLinkHeader(msg))->source,
      (call CXLinkPacket.getLinkHeader(msg))->sn,
      (call CXLinkPacket.getLinkHeader(msg))->destination,
      call CXMacPacket.getMacType(msg));
    //probe received
    if (CXM_PROBE == call CXMacPacket.getMacType(msg)){
      //is it ours?
      if(state == S_CHECK && probe != NULL 
        && (call CXLinkPacket.getLinkHeader(msg))->source 
           == (call CXLinkPacket.getLinkHeader(probe))->source
          && call CXLinkPacket.getSn(msg) == call CXLinkPacket.getSn(probe)){
          //yup. src/sn match.
          cdbg(LPP, "ACK msg %p %u %u probe %p %u %u\r\n",
            msg,
            (call CXLinkPacket.getLinkHeader(msg))->source,
            call CXLinkPacket.getSn(msg),
            probe, 
            (call CXLinkPacket.getLinkHeader(probe))->source,
            call CXLinkPacket.getSn(probe));
          state = S_AWAKE;
          firstWakeup = TRUE;
          call Pool.put(probe);
          probe = NULL;
          cinfo(LPP, "WAKE\r\n");
          signal LppControl.wokenUp(activeNS);
          return msg;
        }else{
          //nope: it's from another node. record it for topology/time
          //synch.
          return signal LppProbeSniffer.sniffProbe(msg);
        }
    } else {
      am_addr_t src = (call CXLinkPacket.getLinkHeader(msg))->source;
      uint16_t sn = (call CXLinkPacket.getLinkHeader(msg))->sn;
      //if state is check and we hear an ongoing non-probe transmission, 
      // we should wake up and stop waiting to hear our probe come
      // back.
      //N.B: allowing this to happen means that it's possible for a
      //  node to send a probe and wake up with no other nodes hearing
      //  it. This means that the topology info for the network may be
      //  in complete.
      if (state == S_CHECK){
        cdbg(LPP, "ACTIVITY free probe %p \r\n",
          probe); 
        state = S_AWAKE;
        firstWakeup = TRUE;
        signal LppControl.wokenUp(activeNS);
        cinfo(LPP, "WAKE\r\n");
        if (probe !=NULL){
          call Pool.put(probe);
          probe = NULL;
        }
      }
      //N.B: if state is S_IDLE, then we still signal this up but we
      //do not wake up. This can be used, for instance, to force the
      //node to listen without waking up the network.
      //filter duplicates here: generally speaking, the only time we
      //can get duplicates is when a node misses its send deadline and
      //sends it a little bit late. depending on how this goes down,
      //it's possible for a packet to get delayed enough that it gets
      //sent after the original flood has finished.

      if (lastSrc == src && lastSn == sn){
        return msg;
      }else{
        lastSrc = src;
        lastSn = sn;
        return signal Receive.receive(msg, pl, len);
      }
    }
  }

  event void TimeoutCheck.fired(){
    cerror(LPP, "Operation timed out\r\n");
    call StateDump.requestDump();
  }

  event void StateDump.dumpRequested(){
    cerror(LPP, "LPP %x p %p pi %lu\r\n", 
      state, 
      probe,
      probeInterval);
  }


  task void signalWokenUp(){
    state = S_AWAKE;
    cinfo(LPP, "WAKE\r\n");
    signal LppControl.wokenUp(activeNS);
  }

  /**
   * N.B: this does NOT start waking up the rest of the network. It's
   * up to the layer above to start receiving with retx on. This lets
   * the layer above figure out how long it should sit around doing
   * ACKs to help out. 
   */
  command error_t LppControl.wakeup(uint8_t ns){
    switch (state){
      case S_OFF:
        return EOFF;
      case S_IDLE:
        activeNS = ns;
        post signalWokenUp();
        return SUCCESS;
      case S_CHECK:
        if (manualWakeupPending){
          return EALREADY;
        }else{
          manualWakeupPending = TRUE;
          manualWakeupNS = ns;
          return SUCCESS;
        }
      case S_AWAKE:
        return EALREADY;
      default:
        return FAIL;
    }
  }

  command bool LppControl.isAwake(){
    return (state == S_AWAKE);
  }

  task void signalFellAsleep(){
    cinfo(LPP, "SLEEP\r\n");
    signal LppControl.fellAsleep();
  }

  command error_t LppControl.sleep(){
    if (state != S_IDLE){
      if (state == S_OFF){
        return EOFF;
      }else{
        error_t error;
        state = S_IDLE;
        error = call SubCXLink.sleep();
        if (error != SUCCESS){
          cerror(LPP, "LPP.s s: %x\r\n", error);
          call StateDump.requestDump();
        }
        call ProbeTimer.startOneShot((LPP_SLEEP_TIMEOUT)+randomize(probeInterval));
        post signalFellAsleep();
        return SUCCESS;
      }
    }else{
      return EALREADY;
    }
  }

  command error_t LppControl.setProbeInterval(uint32_t t){
    if (state != S_OFF){
      probeInterval = t;
      call ProbeTimer.startOneShot(randomize(probeInterval));
      return SUCCESS;
    }else{
      return EOFF;
    }
  }

  command error_t Send.send(message_t* msg, uint8_t len){
    if (call LppControl.isAwake()){
      error_t error;
      //set ttl if not set from above
      if ((call CXLinkPacket.getLinkHeader(msg))->ttl == 0){
        (call CXLinkPacket.getLinkHeader(msg))->ttl = CX_MAX_DEPTH;
      }
      call CXLinkPacket.setAllowRetx(msg, TRUE);
      error = call SubSend.send(msg, call LinkPacket.payloadLength(msg));
      cdbg(LPP, "MS d %x\r\n", call CXMacPacket.getMacType(msg));
      if (error == SUCCESS){
        sending = TRUE;
        call TimeoutCheck.startOneShot(FRAMELEN_SLOW*2*CX_MAX_DEPTH);
      }else{
        cwarn(LPP, "LppS.S %x\r\n", error);
      }
      return error;
    }else{ 
      return ERETRY;
    }
  }

  command void* Send.getPayload(message_t* msg, uint8_t len){
    return call Packet.getPayload(msg, len);
  }

  command uint8_t Send.maxPayloadLength(){
    return call Packet.maxPayloadLength();
  }

  command error_t Send.cancel(message_t* msg){
    return call SubSend.cancel(msg);
  }
  

  command error_t SplitControl.start(){
    return call SubSplitControl.start();
  }

  command error_t SplitControl.stop(){
    return call SubSplitControl.stop();
  }

  event void SubSplitControl.startDone(error_t error){
    if (error == SUCCESS){
      call ProbeTimer.startOneShot(randomize(probeInterval));
      state = S_IDLE;
    }
    signal SplitControl.startDone(error);
  }

  event void SubSplitControl.stopDone(error_t error){
    if (error == SUCCESS){
      state = S_OFF;
    }
    signal SplitControl.stopDone(error);
  }


  command error_t CXLink.setChannel(uint8_t channel){
    return setChannel(channel);
  }

  command error_t CXLink.sleep(){
    return call SubCXLink.sleep();
  }

  default event void LppControl.wokenUp(uint8_t ns){
  }
  default event void LppControl.fellAsleep(){
  }

  default event message_t* LppProbeSniffer.sniffProbe(message_t* msg){
    return msg;
  }

  default event void LppProbeSniffer.sniffDone(error_t error){ }

  command cx_link_stats_t CXLink.getStats(){
    return call SubCXLink.getStats();
  }
}
