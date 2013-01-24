module DualActiveMessageP{
  provides interface SplitControl;
  uses interface SplitControl as RadioSplitControl;
  uses interface SplitControl as SerialSplitControl;

  provides interface AMSend[am_id_t id];
  uses interface AMSend as RadioAMSend[am_id_t id];
  uses interface AMSend as SerialAMSend[am_id_t id];

  uses interface Packet as RadioPacket;
  uses interface Packet as SerialPacket;

  uses interface AMPacket as RadioAMPacket;
  uses interface AMPacket as SerialAMPacket;

} implementation {
  task void startSerialTask();
  task void stopSerialTask();

  command error_t SplitControl.start(){ 
    return call RadioSplitControl.start();
  }

  event void RadioSplitControl.startDone(error_t error){
    if (error != SUCCESS){
      signal SplitControl.startDone(error);
    }else{
      post startSerialTask();
    }
  }

  task void startSerialTask(){
    error_t err = call SerialSplitControl.start();
    if (err != SUCCESS){
      signal SplitControl.startDone(err);
    }
  }

  event void SerialSplitControl.startDone(error_t error){
    signal SplitControl.startDone(error);
  }

  command error_t SplitControl.stop(){ 
    return call RadioSplitControl.stop();
  }

  event void RadioSplitControl.stopDone(error_t error){
    if (error != SUCCESS){
      signal SplitControl.stopDone(error);
    }else{
      post stopSerialTask();
    }
  }

  task void stopSerialTask(){
    error_t err = call SerialSplitControl.stop();
    if (err != SUCCESS){
      signal SplitControl.stopDone(err);
    }
  }

  event void SerialSplitControl.stopDone(error_t error){
    signal SplitControl.stopDone(error);
  }
  
  command error_t AMSend.cancel[am_id_t id](message_t* msg){
    error_t err_r = call RadioAMSend.cancel[id](msg);
    error_t err_s = call SerialAMSend.cancel[id](msg);
    if (err_r == SUCCESS || err_s == SUCCESS){
      return SUCCESS;
    }else{
      //return the one with the highest error code (if one is more
      //specific than FAIL, at least we'll see it)
      return (err_r > err_s)? err_r: err_s;
    }
  }
  
  command error_t AMSend.send[am_id_t id](am_addr_t addr, 
      message_t* msg, uint8_t len){
    return call RadioAMSend.send[id](addr, msg, len);
  }

  event void RadioAMSend.sendDone[am_id_t id](message_t* msg, 
      error_t error){
    uint8_t pll = call RadioPacket.payloadLength(msg);
    void* rpl = call RadioPacket.getPayload(msg, 
      call RadioPacket.payloadLength(msg));
    void* spl = call SerialPacket.getPayload(msg, 
      pll);
    
    if (error == SUCCESS){
      memmove(spl, rpl, pll);
      error = call SerialAMSend.send[id](call RadioAMPacket.destination(msg),
        msg, pll);
      if (error != SUCCESS){
        memmove(rpl, spl, pll);
        signal AMSend.sendDone[id](msg, error);
      }
    }else{
      signal AMSend.sendDone[id](msg, error);
    }

  }

  event void SerialAMSend.sendDone[am_id_t id](message_t* msg, 
      error_t error){
    if (id != AM_PRINTF_MSG){
      uint8_t pll = call SerialPacket.payloadLength(msg);
      void* rpl = call RadioPacket.getPayload(msg, 
        pll);
      void* spl = call SerialPacket.getPayload(msg, 
        pll);
      memmove(rpl, spl, pll);
      signal AMSend.sendDone[id](msg, error);
    }
  }

  command uint8_t AMSend.maxPayloadLength[am_id_t id](){
    uint8_t rpl = call RadioAMSend.maxPayloadLength[id]();
    uint8_t spl = call SerialAMSend.maxPayloadLength[id]();
    return (rpl < spl)? rpl : spl;
  }

  command void* AMSend.getPayload[am_id_t id](message_t* msg, uint8_t len){
    return call RadioPacket.getPayload(msg, len);
  }
}
