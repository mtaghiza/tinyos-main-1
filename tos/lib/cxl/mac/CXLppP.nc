
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

  command error_t LppControl.wakeup(){
    if (state == S_OFF){
      return EOFF;
    }else{
      error_t error;
      keepAlive = TRUE;
      state = S_AWAKE;
      error = call CXLink.rx(RX_TIMEOUT_MAX, TRUE);
      printf("cxl.rx: %x\r\n", error);
      //TODO: start sending keep-alive's: should go out some
      //  time before sleep timer expires.
      return error;
    }
  }

  command error_t LppControl.sleep(){
    if (state != S_IDLE){
      if (state == S_OFF){
        return EOFF;
      }else{
        call CXLink.sleep();
        state = S_IDLE;
        call ProbeTimer.startOneShot(randomize(probeInterval));
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
          call CXLinkPacket.len(probe));
        if (SUCCESS != error){
          printf("sp: %x\r\n", error);
          call Pool.put(probe);
          call ProbeTimer.startOneShot(randomize(probeInterval));
        }
      }
    }
  }

  event void SubSend.sendDone(message_t* msg, error_t error){
    if (state == S_CHECK){
      if (msg == probe){
        //immediately after probe is sent, listen for a short period
        //of time.
        call CXLink.rx(CHECK_TIMEOUT, FALSE);
      }else{
        printf("sendDone in check, but it's not a probe.\r\n");
        call Pool.put(msg);
        probe = NULL;
      }
    }else{
      signal Send.sendDone(msg, error);
    }
  }

  event message_t* SubReceive.receive(message_t* msg, void* pl, uint8_t len){
    printf("sr.r\r\n");
    switch (call CXMacPacket.getMacType(msg)){
      case CXM_DATA:
        //fall through
      case CXM_CTS:
        //fall through
      case CXM_RTS:
        if (state == S_AWAKE){
          call SleepTimer.startOneShot(LPP_SLEEP_TIMEOUT);
        }
        //TODO: adjust pl position
        return signal Receive.receive(msg, pl, len);
        break;

      case CXM_KEEPALIVE:
        if (state == S_AWAKE){
          call SleepTimer.startOneShot(LPP_SLEEP_TIMEOUT);
        }
        return msg;

      case CXM_PROBE:
        if (state == S_CHECK 
          && (call CXLinkPacket.getLinkHeader(msg))->source 
             == (call CXLinkPacket.getLinkHeader(probe))->source){
          state = S_AWAKE;
          printf("woken up\r\n");
          call SleepTimer.startOneShot(LPP_SLEEP_TIMEOUT);
          call Pool.put(probe);
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
    printf("back to sleep\r\n");
    state = S_IDLE;
    call CXLink.sleep();
    if (! call ProbeTimer.isRunning()){
      call ProbeTimer.startOneShot(randomize(probeInterval));
    }
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
    //TODO: set TTL
    return FAIL;
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
