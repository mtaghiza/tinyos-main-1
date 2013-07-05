
 #include "CXMac.h"
 #include "CXLppDebug.h"
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
} implementation {
  
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

  uint32_t randomize(uint32_t mean){
    uint32_t ret = (mean/2) + (call Random.rand32())%mean ;
    return ret;
  }

  event void ProbeTimer.fired(){
    if (state == S_IDLE){
      if (forceRx){
        //in the middle of a sniff: try probing again later.
        call ProbeTimer.startOneShot(randomize(probeInterval));
      } else {
        state = S_CHECK;
        probe = call Pool.get();
        if (probe){
          error_t error;
          call Packet.clear(probe);
          call CXMacPacket.setMacType(probe, CXM_PROBE);
          (call CXLinkPacket.getLinkHeader(probe))->ttl = 2;
          (call CXLinkPacket.getLinkHeader(probe))->destination =
            AM_BROADCAST_ADDR;
          call CXLinkPacket.setAllowRetx(probe, FALSE);
          call Packet.setPayloadLength(probe, 0);
          error = call SubSend.send(probe, 
            call LinkPacket.payloadLength(probe));
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
          cerror(LPP, "LPP ss.sd ack rx %x\r\n", error);
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

    //Still in S_CHECK? we didn't hear our probe come back. go to
    //  sleep.
    if (state == S_CHECK){
      error_t error = call SubCXLink.sleep();
      if (error != SUCCESS){
        cerror(LPP, "LPP rxd s %x\r\n", error);
      }
      call Pool.put(probe);
      probe = NULL;
      call ProbeTimer.startOneShot(randomize(probeInterval));
      state = S_IDLE;
    } else if (state == S_AWAKE){
      if (firstWakeup){
        firstWakeup = FALSE;
      }else{
        signal CXLink.rxDone();
      }
    }else if (forceRx){
      forceRx = FALSE;
      signal CXLink.rxDone();
    } else {
      cerror(LPP, "Unexpected RXDone %x\r\n", state);
      //if we let upper layer request RX without doing a real wakeup
      //(e.g. to sniff for traffic), then this can/should happen.
    }
  }

  command error_t CXLink.rx(uint32_t timeout, bool retx){
    if (state == S_OFF){
      return EOFF;
    } else if (state == S_IDLE){
      if (retx == TRUE){
        return EINVAL;
      } else{
        error_t error = call SubCXLink.rx(timeout, retx);
        if (SUCCESS == error && state != S_AWAKE){
          forceRx = TRUE;
        }
        return error;
      }
    } else if (state == S_CHECK){
      return ERETRY;
    }else if (state == S_AWAKE){
      return call SubCXLink.rx(timeout, retx);
    }else{
      cerror(LPP, "Unexpected state %x at rx\r\n", state); 
      return FAIL;
    }
  }

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
          signal LppControl.wokenUp();
          return msg;
        }else{
          //nope: it's from another node. record it for topology/time
          //synch.
          signal LppProbeSniffer.sniffProbe(call CXLinkPacket.source(msg));
          return msg;
        }
    } else {
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
        signal LppControl.wokenUp();
        cinfo(LPP, "WAKE\r\n");
        if (probe !=NULL){
          call Pool.put(probe);
          probe = NULL;
        }
      }
      //N.B: if state is S_IDLE, then we still signal this up but we
      //do not wake up. This can be used, for instance, to force the
      //node to listen without waking up the network.
      return signal Receive.receive(msg, pl, len);
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
    signal LppControl.wokenUp();
  }

  /**
   * N.B: this does NOT start waking up the rest of the network. It's
   * up to the layer above to start receiving with retx on. This lets
   * the layer above figure out how long it should sit around doing
   * ACKs to help out. 
   */
  command error_t LppControl.wakeup(){
    switch (state){
      case S_OFF:
        return EOFF;
      case S_IDLE:
        post signalWokenUp();
        return SUCCESS;
      case S_CHECK:
        return EALREADY;
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
        call ProbeTimer.startOneShot((2*LPP_SLEEP_TIMEOUT)+randomize(probeInterval));
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
    return call SubCXLink.setChannel(channel);
  }

  command error_t CXLink.sleep(){
    return call SubCXLink.sleep();
  }

  default event void LppControl.wokenUp(){
  }
  default event void LppControl.fellAsleep(){
  }

  default event void LppProbeSniffer.sniffProbe(am_addr_t src){}
}
