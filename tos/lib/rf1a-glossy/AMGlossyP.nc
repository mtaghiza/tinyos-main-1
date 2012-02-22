#include "AMGlossy.h"
#include "decodeError.h"

generic module AMGlossyP(){
  provides interface AMSend;
  provides interface Receive;
  provides interface AMPacket;

  uses interface AMSend as SubAMSend;
  uses interface AMPacket as SubAMPacket;
  uses interface DelayedSend;
  uses interface Receive as SubReceive;
  uses interface Rf1aPhysical;
  uses interface Rf1aCoreInterrupt;

  uses interface Alarm<TMicro, uint16_t>;
} implementation {
  message_t rx_msg_internal;
  message_t* rx_msg = &rx_msg_internal;
  uint8_t rx_len;
  
  message_t tx_msg_internal;
  message_t* tx_msg = &tx_msg_internal;
  uint8_t tx_len;

  enum{
    S_IDLE,
    S_WAIT_RECEIVE,
    S_COPY_TO_TX,
    S_SEND_START,
    S_ORIGIN_SEND_START,
    S_SEND_READY,
    S_ORIGIN_SENDING,
    S_SENDING,
  };
  
  //TODO: atomicity
  uint8_t state = S_IDLE;


  task void copyToTX(){
    am_glossy_header_t* header = call SubAMSend.getPayload(tx_msg,
      sizeof(am_glossy_header_t));
    error_t error;
    
    //TODO: check src and sn to suppress duplicates

    //copy from rx to tx, update header
    memcpy(call AMSend.getPayload(tx_msg, rx_len), 
      call AMSend.getPayload(rx_msg, rx_len),
      rx_len);
    header -> count += 1;


    //signal the original rx up, swap
    rx_msg = signal Receive.receive(rx_msg, call
      AMSend.getPayload(rx_msg, rx_len - sizeof(am_glossy_header_t)), 
      rx_len - sizeof(am_glossy_header_t));
    
    //first half of rebroadcast
    state = S_SEND_START;

    //TODO: need to PREVENT local address from entering this packet!
    error = call SubAMSend.send(AM_BROADCAST_ADDR, tx_msg, tx_len); 

    if (error != SUCCESS){
      printf("%s: %s\n\r", __FUNCTION__, decodeError(error));
    }
  }

  event message_t* SubReceive.receive(message_t* msg, void* payload,
      uint8_t len){
    if (state == S_WAIT_RECEIVE){
      message_t* swp = rx_msg;
      rx_msg = msg;
      rx_len = len;
      post copyToTX();
      state = S_COPY_TO_TX;
      return swp;
    } else {
      printf("%s Ignore receive: busy\n\r", __FUNCTION__);
      return msg;
    }
  }

  async event void DelayedSend.sendReady(){
    if (state == S_ORIGIN_SEND_START){
      state = S_ORIGIN_SENDING;
      call DelayedSend.completeSend();
    } else if (state == S_SEND_START){
      state = S_SEND_READY;
    } else {
      printf("%s: Unexpected sendReady\n\r", __FUNCTION__);
    }
  }

  async event void Alarm.fired(){
    //TODO: use GPIO to determine how close two relays complete
    //  sending
    if (state == S_SEND_READY){
      call DelayedSend.completeSend();
      state = S_SENDING;
    } else {
      printf("%s: Unexpected alarm\n\r", __FUNCTION__);
    }
  }
  
  async event void Rf1aPhysical.frameStarted () { 
    //TODO: use GPIO to determine how close two relays detect preamble
    call Alarm.start(RETX_DELAY);
    if (state == S_IDLE){
      state = S_WAIT_RECEIVE;
    } else {
      //ok, we got this because we were transmitting. 
      call Alarm.stop();
    }
  }

  //include length of glossy header
  command void* AMSend.getPayload(message_t* msg, uint8_t len){
    return (call SubAMSend.getPayload(msg, len + sizeof(am_glossy_header_t))) 
      + sizeof(am_glossy_header_t);
  }

  command error_t AMSend.send(am_addr_t addr, message_t* msg, 
    uint8_t len){
    if (state != S_IDLE){
      return EBUSY;
    } else {
      error_t error;
      am_glossy_header_t* hdr = call SubAMSend.getPayload(msg, len +
        sizeof(am_glossy_header_t));
      hdr->dest = addr;
      error = call SubAMSend.send(AM_BROADCAST_ADDR, msg, len +
        sizeof(am_glossy_header_t)); 
      if (error == SUCCESS){
        state = S_ORIGIN_SEND_START;
      }
      return error;
    }
  }

  event void SubAMSend.sendDone(message_t* msg, error_t error){
    if (state == S_ORIGIN_SENDING){
      signal AMSend.sendDone(msg, error);
    }else{
      //done forwarding
      //TODO: cache src, sn
    }
    state = S_IDLE;
  }

  command uint8_t AMSend.maxPayloadLength(){
    return call SubAMSend.maxPayloadLength() - sizeof(am_glossy_header_t);
  }

  command error_t AMSend.cancel(message_t* msg){
    //TODO: how to handle?
    return FAIL;
  }

  command am_addr_t AMPacket.address(){
    return call SubAMPacket.address();
  }

  command am_addr_t AMPacket.source(message_t* amsg){
    return ((am_glossy_header_t*)(call SubAMSend.getPayload(amsg,
      sizeof(am_glossy_header_t)))) -> src;
  }

  command void AMPacket.setSource(message_t* amsg, am_addr_t addr){
    ((am_glossy_header_t*)(call SubAMSend.getPayload(amsg,
      sizeof(am_glossy_header_t)))) -> src = addr;
  }
  
  command am_addr_t AMPacket.destination(message_t* msg){
    return ((am_glossy_header_t*)(call SubAMSend.getPayload(msg,
      sizeof(am_glossy_header_t)))) -> dest;
  }
  
  command void AMPacket.setDestination(message_t* msg, am_addr_t addr){
    ((am_glossy_header_t*)(call SubAMSend.getPayload(msg,
      sizeof(am_glossy_header_t)))) -> dest = addr;
  }

  command am_group_t AMPacket.group(message_t* msg){
    return ((am_glossy_header_t*)(call SubAMSend.getPayload(msg,
      sizeof(am_glossy_header_t)))) -> group;
  }

  command void AMPacket.setGroup(message_t* amsg, am_group_t grp){
    ((am_glossy_header_t*)(call SubAMSend.getPayload(amsg,
      sizeof(am_glossy_header_t)))) -> group = grp;
  }

  command am_group_t AMPacket.localGroup(){
    return call SubAMPacket.localGroup();
  }

  command am_id_t AMPacket.type(message_t* msg){
    return ((am_glossy_header_t*)(call SubAMSend.getPayload(msg,
      sizeof(am_glossy_header_t)))) -> type;
  }

  command void AMPacket.setType(message_t* msg, am_id_t t){
    ((am_glossy_header_t*)(call SubAMSend.getPayload(msg,
      sizeof(am_glossy_header_t)))) -> type = t;
  }

  command bool AMPacket.isForMe(message_t* amsg){
    am_addr_t dest = call AMPacket.destination(amsg);
    am_group_t grp = call AMPacket.group(amsg);
    return (grp == call AMPacket.localGroup() && 
      (dest == call AMPacket.address() || dest == AM_BROADCAST_ADDR));
  }

  //Use this if configurable GDO signals desired (See
  //  HplMsp430Rf1aP.configure: interrupts are hard-coded. Probably
  //  just need the frame-start interrupt)
  async event void Rf1aCoreInterrupt.interrupt(uint16_t iv){ }

  //unused events
  async event void Rf1aPhysical.sendDone (int result) { }
  async event void Rf1aPhysical.receiveStarted (unsigned int length) { }
  async event void Rf1aPhysical.receiveDone (uint8_t* buffer,
    unsigned int count, int result) { }
  async event void Rf1aPhysical.receiveBufferFilled (uint8_t* buffer,
    unsigned int count) { }
  async event void Rf1aPhysical.clearChannel () { }
  async event void Rf1aPhysical.carrierSense () { }
  async event void Rf1aPhysical.released () { }

  
}
