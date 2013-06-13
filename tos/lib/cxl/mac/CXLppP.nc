
 #include "CXMac.h"
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

  uses interface Timer<TMilli> as ProbeTimer;
  uses interface Timer<TMilli> as SleepTimer;
  uses interface Timer<TMilli> as KeepAliveTimer;
  uses interface Random;
} implementation {
  
  enum {
    S_OFF = 0,
    S_IDLE = 1,
    S_CHECK = 2,
    S_AWAKE = 3
  };
  bool keepAlive = FALSE;

  uint8_t state = S_OFF;
  uint32_t probeInterval = LPP_DEFAULT_PROBE_INTERVAL;
  message_t* probe;

  uint32_t randomize(uint32_t mean){
    uint32_t ret = (mean/2) + (call Random.rand32())%mean ;
    return ret;
  }

  void pushSleep(){
    if (state == S_AWAKE ){
      if (keepAlive){
        call KeepAliveTimer.startOneShot(LPP_SLEEP_TIMEOUT/2);
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
//      printf("cxl.rx: %x\r\n", error);
      signal LppControl.wokenUp();
      return error;
    }
  }

  command bool LppControl.isAwake(){
    return (state == S_AWAKE);
  }

  command error_t LppControl.sleep(){
    if (state != S_IDLE){
      if (state == S_OFF){
        return EOFF;
      }else{
        state = S_IDLE;
        keepAlive = FALSE;
        call CXLink.sleep();
        call ProbeTimer.startOneShot((2*LPP_SLEEP_TIMEOUT)+randomize(probeInterval));
        call SleepTimer.stop();
        call KeepAliveTimer.stop();
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
        printf("sprobe %p\r\n", probe);
        error = call SubSend.send(probe, 
          call CXLinkPacket.len(probe));
        if (SUCCESS != error){
          printf("sp: %x\r\n", error);
          call Pool.put(probe);
          call ProbeTimer.startOneShot(randomize(probeInterval));
        }
      }
    }
  }
  
  message_t* keepAliveMsg;
  event void KeepAliveTimer.fired(){
    keepAliveMsg = call Pool.get();
    if (keepAliveMsg){
      error_t error;
      call Packet.clear(keepAliveMsg);
      call CXMacPacket.setMacType(keepAliveMsg, CXM_KEEPALIVE);
      (call CXLinkPacket.getLinkHeader(keepAliveMsg))->ttl = CX_MAX_DEPTH;
      call Packet.setPayloadLength(keepAliveMsg, 0);
      call CXLinkPacket.setAllowRetx(keepAliveMsg, TRUE);
      printf("ska %p\r\n", keepAliveMsg);
      error = call SubSend.send(keepAliveMsg,
        call CXLinkPacket.len(keepAliveMsg));
      if (SUCCESS != error){
        printf("ska: %x\r\n", error);
        call Pool.put(keepAliveMsg);
        call KeepAliveTimer.startOneShot(CX_KEEPALIVE_RETRY);
      }
    }
    pushSleep();
  }

  event void SubSend.sendDone(message_t* msg, error_t error){
    printf("sd ");
    if (state == S_CHECK){
      if (msg == probe){
        printf("probe\r\n");
        //immediately after probe is sent, listen for a short period
        //of time.
        call CXLink.rx(CHECK_TIMEOUT, FALSE);
      }else{
        printf("?\r\n");
        call Pool.put(msg);
        probe = NULL;
      }
    }else{
      if (keepAlive && msg == keepAliveMsg){
        printf("ka\r\n");
        call Pool.put(keepAliveMsg);
      }else{
        printf("up\r\n");
        signal Send.sendDone(msg, error);
      }
      pushSleep();
      call CXLink.rx(RX_TIMEOUT_MAX, TRUE);
    }
  }

  event message_t* SubReceive.receive(message_t* msg, void* pl, uint8_t len){
//    printf("sr.r\r\n");
    switch (call CXMacPacket.getMacType(msg)){
      case CXM_DATA:
        //fall through
      case CXM_CTS:
        //fall through
      case CXM_RTS:
        if (state == S_AWAKE){
          pushSleep();
        }
        //TODO: adjust pl position
        return signal Receive.receive(msg, pl, len);
        break;

      case CXM_KEEPALIVE:
        if (state == S_AWAKE){
          pushSleep();
        }
        return msg;

      case CXM_PROBE:
        if (state == S_CHECK 
          && (call CXLinkPacket.getLinkHeader(msg))->source 
             == (call CXLinkPacket.getLinkHeader(probe))->source){
          state = S_AWAKE;
          pushSleep();
          call Pool.put(probe);
          signal LppControl.wokenUp();
        }
        //probes DO NOT extend sleep timer.
        //TODO: probably want to sniff these.
        return msg;

      default:
        printf("Unrecognized mac type %x\r\n", 
          call CXMacPacket.getMacType(msg));
        return msg;
    }
  }

  event void SleepTimer.fired(){
    signal LppControl.fellAsleep();
    state = S_IDLE;
    call CXLink.sleep();
    //We wait for a good long while before probing again to minimize
    //the chance of spurious wakeups.
    call ProbeTimer.startOneShot((2*LPP_SLEEP_TIMEOUT)+randomize(probeInterval));
  }
  
  event void CXLink.rxDone(){
    printf("rxd\r\n");
    //Still in S_CHECK? we didn't hear our probe come back. go to
    //  sleep.
    if (state == S_CHECK){
      call CXLink.sleep();
      call Pool.put(probe);
      call ProbeTimer.startOneShot(randomize(probeInterval));
      state = S_IDLE;
    }
    if (state == S_AWAKE){
      //start next RX.
      call CXLink.rx(RX_TIMEOUT_MAX, TRUE);
    }
  }
  
  command error_t Send.send(message_t* msg, uint8_t len){
    printf("send %p\r\n", msg);
    if (call LppControl.isAwake()){
      (call CXLinkPacket.getLinkHeader(msg))->ttl = CX_MAX_DEPTH;
      call Packet.setPayloadLength(msg, len);
      call CXMacPacket.setMacType(msg, CXM_DATA);
      return call SubSend.send(msg, call CXLinkPacket.len(msg));
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

  event void CXLink.toneSent(){}
  event void CXLink.toneReceived(bool received){}
}
