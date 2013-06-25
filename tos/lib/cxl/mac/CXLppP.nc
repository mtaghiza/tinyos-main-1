
 #include "CXMac.h"
 #include "CXLppDebug.h"
module CXLppP {
  provides interface LppControl;

  provides interface SplitControl;
  provides interface Send;
  provides interface Receive;

  uses interface SplitControl as SubSplitControl;
  uses interface Send as SubSend;
  uses interface Receive as SubReceive;

  uses interface Pool<message_t>;

  uses interface CXLink;
  uses interface CXLinkPacket;
  uses interface CXMacPacket;
  //This packet interface goes to body of mac packet
  uses interface Packet;
  //and this goes to body of link packet
  uses interface Packet as LinkPacket;

  uses interface Timer<TMilli> as ProbeTimer;
  uses interface Timer<TMilli> as SleepTimer;
  uses interface Timer<TMilli> as KeepAliveTimer;
  uses interface Random;

  uses interface Timer<TMilli> as TimeoutCheck;

  uses interface StateDump;
} implementation {
  
  enum {
    S_OFF = 0,
    S_IDLE = 1,
    S_CHECK = 2,
    S_AWAKE = 3
  };
  bool keepAlive = FALSE;
  message_t* keepAliveMsg;

  bool sending = FALSE;

  uint8_t state = S_OFF;
  uint32_t probeInterval = LPP_DEFAULT_PROBE_INTERVAL;
  message_t* probe;

  event void TimeoutCheck.fired(){
    cerror(LPP, "Operation timed out\r\n");
    call StateDump.requestDump();
  }

  event void StateDump.dumpRequested(){
    cerror(LPP, "LPP %x p %p ka %x kam %p pi %lu\r\n", 
      state, 
      probe,
      keepAlive, 
      keepAliveMsg, 
      probeInterval);
  }

  uint32_t randomize(uint32_t mean){
    uint32_t ret = (mean/2) + (call Random.rand32())%mean ;
    return ret;
  }

  void pushSleep(){
    if (state == S_AWAKE ){
      if (keepAlive){
        call KeepAliveTimer.startOneShot(LPP_SLEEP_TIMEOUT/4);
      } else {
        call SleepTimer.startOneShot(LPP_SLEEP_TIMEOUT);
      }
    }
  }

  command error_t LppControl.wakeup(){
    if (state == S_OFF){
      return EOFF;
    }else{
      error_t error;
      keepAlive = TRUE;
      state = S_AWAKE;
      pushSleep();
      error = call CXLink.rx(RX_TIMEOUT_MAX, TRUE);
      if (SUCCESS == error){
        call TimeoutCheck.startOneShot(RX_TIMEOUT_MAX_SLOW);
      }else{
        cerror(LPP, "LPP.w rx %x\r\n", error);
      }
      cinfo(LPP, "WAKE\r\n");
      signal LppControl.wokenUp();
      return error;
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
        keepAlive = FALSE;
        error = call CXLink.sleep();
        if (error != SUCCESS){
          cerror(LPP, "LPP.s s: %x\r\n", error);
          call StateDump.requestDump();
        }
        call ProbeTimer.startOneShot((2*LPP_SLEEP_TIMEOUT)+randomize(probeInterval));
        call SleepTimer.stop();
        call KeepAliveTimer.stop();
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


  event void ProbeTimer.fired(){
    if (state == S_IDLE){
      state = S_CHECK;
      probe = call Pool.get();
      if (probe){
        error_t error;
        call Packet.clear(probe);
        call CXMacPacket.setMacType(probe, CXM_PROBE);
        (call CXLinkPacket.getLinkHeader(probe))->ttl = 2;
        call CXLinkPacket.setAllowRetx(probe, FALSE);
        call Packet.setPayloadLength(probe, 0);
        error = call SubSend.send(probe, 
          call LinkPacket.getPayloadLength(probe));
        cdbg(LPP, "MS p\r\n");
        if (SUCCESS != error){
          cerror(LPP, "pt.f ss %x\r\n", error);
          call Pool.put(probe);
          probe = NULL;
          call ProbeTimer.startOneShot(randomize(probeInterval));
        }else{
          sending = TRUE;
          call TimeoutCheck.startOneShot(FRAMELEN_SLOW*2*2);
        }
      }
    }
  }
  
  event void KeepAliveTimer.fired(){
    keepAliveMsg = call Pool.get();
    if (keepAliveMsg){
      error_t error;
      call Packet.clear(keepAliveMsg);
      call CXMacPacket.setMacType(keepAliveMsg, CXM_KEEPALIVE);
      (call CXLinkPacket.getLinkHeader(keepAliveMsg))->ttl = CX_MAX_DEPTH;
      (call CXLinkPacket.getLinkHeader(keepAliveMsg))->destination = AM_BROADCAST_ADDR;
      call Packet.setPayloadLength(keepAliveMsg, 0);
      call CXLinkPacket.setAllowRetx(keepAliveMsg, TRUE);
      error = call SubSend.send(keepAliveMsg,
        call LinkPacket.getPayloadLength(keepAliveMsg));
      cdbg(LPP, "MS k\r\n");
      if (SUCCESS != error){
        cerror(LPP, "kat.f ss %x\r\n", error);
        call Pool.put(keepAliveMsg);
        keepAliveMsg = NULL;
        call KeepAliveTimer.startOneShot(CX_KEEPALIVE_RETRY);
      }else{
        sending = TRUE;
        call TimeoutCheck.startOneShot(FRAMELEN_SLOW*CX_MAX_DEPTH*2);
      }
    }
    pushSleep();
  }

  event void SubSend.sendDone(message_t* msg, error_t error){
    call TimeoutCheck.stop();
    sending = FALSE;
    cdbg(LPP, "MS SD\r\n");
    if (error != SUCCESS){
      cwarn(LPP, "LPP ss.sd %x\r\n", error);
    }
    cinfo(LPP, "MTX %x %u %lu %u %x\r\n",
      error,
      (call CXLinkPacket.getLinkHeader(msg))->source,
      (call CXLinkPacket.getLinkHeader(msg))->sn,
      (call CXLinkPacket.getLinkHeader(msg))->destination,
      call CXMacPacket.getMacType(msg));
    if (state == S_CHECK){
      if (msg == probe){
        //immediately after probe is sent, listen for a short period
        //of time.
        error_t err = call CXLink.rx(CHECK_TIMEOUT, FALSE);
        if (err == SUCCESS){
          call TimeoutCheck.startOneShot(CHECK_TIMEOUT_SLOW);
        } else {
          cerror(LPP, "LPP ss.sd ack rx %x\r\n", error);
        }

      }else{
        call Pool.put(msg);
        probe = NULL;
      }
    }else{
      error_t err;
      if (keepAlive && msg == keepAliveMsg){
        call Pool.put(keepAliveMsg);
        keepAliveMsg = NULL;
      }else{
        signal Send.sendDone(msg, error);
      }
      pushSleep();
      err = call CXLink.rx(RX_TIMEOUT_MAX, TRUE);
      if (err == SUCCESS) {
        call TimeoutCheck.startOneShot(RX_TIMEOUT_MAX_SLOW);
      } else {
        cerror(LPP, "LPP ss.sd tx rx %x\r\n", error);
      }
    }
  }

  event message_t* SubReceive.receive(message_t* msg, void* pl, uint8_t len){
    cinfo(LPP, "MRX %u %lu %u %x\r\n",
      (call CXLinkPacket.getLinkHeader(msg))->source,
      (call CXLinkPacket.getLinkHeader(msg))->sn,
      (call CXLinkPacket.getLinkHeader(msg))->destination,
      call CXMacPacket.getMacType(msg));

    switch (call CXMacPacket.getMacType(msg)){
      case CXM_DATA:
      case CXM_CTS:
      case CXM_RTS:
      case CXM_KEEPALIVE:
        //if state is check and we hear an ongoing non-probe transmission, 
        // we should wake up and stop waiting to hear our probe come
        // back.
        if (state == S_CHECK){
          cdbg(LPP, "ACTIVITY free probe %p \r\n",
            probe); 
          state = S_AWAKE;
          signal LppControl.wokenUp();
          cinfo(LPP, "WAKE\r\n");
          if (probe !=NULL){
            call Pool.put(probe);
            probe = NULL;
          }
        }
        if (state == S_AWAKE){
          pushSleep();
        }
        if (call CXMacPacket.getMacType(msg) == CXM_KEEPALIVE){
          return msg;
        }else{
          return signal Receive.receive(msg, pl, len);
        }
        break;

      case CXM_PROBE:
        if (state == S_CHECK && probe != NULL
          && (call CXLinkPacket.getLinkHeader(msg))->source 
             == (call CXLinkPacket.getLinkHeader(probe))->source
          && call CXLinkPacket.getSn(msg) == call CXLinkPacket.getSn(probe)){
          cdbg(LPP, "ACK msg %p %u %lu probe %p %u %lu\r\n",
            msg,
            (call CXLinkPacket.getLinkHeader(msg))->source,
            call CXLinkPacket.getSn(msg),
            probe, 
            (call CXLinkPacket.getLinkHeader(probe))->source,
            call CXLinkPacket.getSn(probe));
          state = S_AWAKE;
          pushSleep();
          call Pool.put(probe);
          probe = NULL;
          cinfo(LPP, "WAKE\r\n");
          signal LppControl.wokenUp();
        }
        //probes DO NOT extend sleep timer.
        //TODO: probably want to sniff these.
        return msg;

      default:
        return msg;
    }
  }

  event void SleepTimer.fired(){
    error_t error;
    cinfo(LPP, "SLEEP\r\n");
    signal LppControl.fellAsleep();
    state = S_IDLE;
    error = call CXLink.sleep();
    if (error != SUCCESS){
      cerror(LPP, "LPP st.f s %x\r\n", error);
    } 
    //We wait for a good long while before probing again to minimize
    //the chance of spurious wakeups.
    call ProbeTimer.startOneShot((2*LPP_SLEEP_TIMEOUT)+randomize(probeInterval));
  }
  
  event void CXLink.rxDone(){
    call TimeoutCheck.stop();
    //Still in S_CHECK? we didn't hear our probe come back. go to
    //  sleep.
    if (state == S_CHECK){
      error_t error = call CXLink.sleep();
      if (error != SUCCESS){
        cerror(LPP, "LPP rxd s %x\r\n", error);
      }
      call Pool.put(probe);
      probe = NULL;
      call ProbeTimer.startOneShot(randomize(probeInterval));
      state = S_IDLE;
    }
    if (state == S_AWAKE && ! sending){
      //start next RX.
      error_t error = call CXLink.rx(RX_TIMEOUT_MAX, TRUE);
      
      if (error == SUCCESS){
        call TimeoutCheck.startOneShot(RX_TIMEOUT_MAX_SLOW);
      }else{
        cerror(LPP, "LPP rxd rx %x\r\n", error);
      }
    }
  }
  
  command error_t Send.send(message_t* msg, uint8_t len){
    if (call LppControl.isAwake()){
      error_t error;
      pushSleep();
      (call CXLinkPacket.getLinkHeader(msg))->ttl = CX_MAX_DEPTH;
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
      call ProbeTimer.startPeriodic(LPP_DEFAULT_PROBE_INTERVAL);
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

  default event void LppControl.wokenUp(){
  }
  default event void LppControl.fellAsleep(){
  }
}
