/** 
 * Sub-send layer below active message impl (and above physical send)
 * to provide flood-based routing/duty cycling.
 *
 * @author Doug Carlson <carlson@cs.jhu.edu>
 */

#include "CX.h"
#include "decodeError.h"

module Rf1aCXFloodP {
  provides interface Send;
  provides interface Receive;
  provides interface SplitControl;
  provides interface PacketAcknowledgements;
  provides interface CXFloodControl;

  uses interface Send as SubSend;
  uses interface Receive as SubReceive;

  uses interface SplitControl as SubSplitControl;
  //should probably roll this into rf1aphysical
  uses interface DelayedSend;
  uses interface Rf1aPhysical;
  uses interface CXPacket;
  uses interface Packet as LayerPacket;
  uses interface Ieee154Packet;
  uses interface Packet as SubPacket;

  provides interface GetNow<bool> as GetCCACheck;
  provides interface GetNow<bool> as GetFastReTX;

  //only have this here because we need to pull address out of it,
  //whooops
  uses interface AMPacket;

  uses interface Alarm<TMicro, uint16_t>;
  //TODO: 32khz alarm for framing
}
implementation {

  message_t rx_msg_internal;
  message_t* rx_msg = &rx_msg_internal;
  uint8_t rx_len;
  
  message_t tx_msg_internal;
  message_t* tx_msg = &tx_msg_internal;

  uint16_t lastSrc;
  uint16_t lastSn;
  uint16_t mySn;

  enum{
    S_IDLE,
    S_WAIT_RECEIVE,
    S_COPY_TO_TX,
    S_SEND_START,
    S_ORIGIN_SEND_START,
    S_SEND_READY,
    S_ORIGIN_SENDING,
    S_SENDING,
  } ;

  //TODO: atomicity
  uint8_t state = S_IDLE;

  cx_header_t* getHeader(message_t* msg){
    return (cx_header_t*)(call SubSend.getPayload(msg, 0));
  }

  void printHeaders(message_t* msg){
    rf1a_ieee154_t* h154 = (rf1a_ieee154_t*)(&(msg->data));
    cx_header_t* hCX = (cx_header_t*)(call SubPacket.getPayload(msg, 0));
    rf1a_nalp_am_t* hAM = (rf1a_nalp_am_t*)(call LayerPacket.getPayload(msg, 0));

    printf("Headers for %p\n\r", msg);
    printf("15.4 (%p) \n\r", h154);
    printf(" fcf %d\n\r", h154->fcf);
    printf(" dsn %d\n\r", h154->dsn);
    printf(" pan (%x)\n\r", call Ieee154Packet.pan(msg));
    printf(" destination (%x)\n\r", call Ieee154Packet.destination(msg));
    printf(" source (%x)\n\r", call Ieee154Packet.source(msg));

    printf("CX (%p) \n\r", hCX);
    printf(" source (%x)\n\r", call CXPacket.source(msg));
    printf(" destination %x (%x)\n\r", hCX->destination, call
      CXPacket.destination(msg));
    printf(" sn %x (%x)\n\r", hCX->sn, call CXPacket.sn(msg));
    printf(" count %x (%x)\n\r", hCX->count, call CXPacket.count(msg));
    printf(" type %x (%x)\n\r", hCX->type, call CXPacket.type(msg));

    printf("AM (%p) \n\r", hAM);

  }

  const char* decodeState(uint8_t state_){
    switch(state_){
      case S_IDLE:
        return "S_IDLE";
      case S_WAIT_RECEIVE:
        return "WAIT_RECEIVE";
      case S_COPY_TO_TX:
        return "COPY_TO_TX";
      case S_SEND_START:
        return "SEND_START";
      case S_ORIGIN_SEND_START:
        return "ORIGIN_SEND_START";
      case S_SEND_READY:
        return "SEND_READY";
      case S_ORIGIN_SENDING:
        return "ORIGIN_SENDING";
      case S_SENDING:
        return "SENDING";
      default:
        return "Unknown";
    }
  }

  void copyToTX (){
//    cx_header_t* header = getHeader(tx_msg);
    error_t error;

    //copy from rx to tx, update header
    memcpy(tx_msg, rx_msg, sizeof(message_t));
//      call SubSend.getPayload(tx_msg, rx_len), 
//      call SubSend.getPayload(rx_msg, rx_len),
//      rx_len);
    call CXPacket.setCount(tx_msg, 1 + (call CXPacket.count(tx_msg)));
    //TODO: should be a little more sophisticated than this. 
    if (call CXPacket.source(tx_msg) == lastSrc && call CXPacket.sn(tx_msg) == lastSn){
      call Alarm.stop();
      state = S_IDLE;
      printf("Duplicate: %u == %u and %u == %u\n\r", call CXPacket.source(tx_msg), lastSrc, call CXPacket.sn(tx_msg),  lastSn);
      return;
    }
    lastSrc = call CXPacket.source(tx_msg);
    lastSn = call CXPacket.sn(tx_msg);

    //unstash the destination from cx header
    call AMPacket.setDestination(rx_msg, call CXPacket.destination(rx_msg));
    //signal the original rx up, swap
    //TODO: this should probably be delayed so that the application is
    //  less likely to do something stupid while we're in a
    //  timing-critical period
    rx_msg = signal Receive.receive(rx_msg, call
      LayerPacket.getPayload(rx_msg, rx_len - sizeof(cx_header_t)), 
      rx_len - sizeof(cx_header_t));
    
    //first half of rebroadcast
    state = S_SEND_START;
    #ifdef DEBUG_FLOOD
    printHeaders(tx_msg);
    #endif
    error = call SubSend.send(tx_msg, rx_len); 

    if (error != SUCCESS){
      printf("%s: %s\n\r", __FUNCTION__, decodeError(error));
    }
  }

  task void copyToTX_task(){
    copyToTX();
  }

  event message_t* SubReceive.receive(message_t* msg, void* payload,
      uint8_t len){
    if (state == S_WAIT_RECEIVE){
      message_t* swp = rx_msg;
      rx_msg = msg;
      rx_len = len;
      //TODO: maybe this should be a direct call to copyToTX
      post copyToTX_task();
      state = S_COPY_TO_TX;
      return swp;
    } else {
      printf("Ignore rx (%x %d): busy\n\r", call CXPacket.source(msg), call CXPacket.sn(msg));
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
      printf("%s: Unexpected sendReady: %s\n\r", __FUNCTION__, decodeState(state));
    }
  }

  async event void Alarm.fired(){
    if (state == S_SEND_READY){
      call DelayedSend.completeSend();
      state = S_SENDING;
    } else if(state == S_WAIT_RECEIVE){
      state = S_IDLE;
      printf("RETX expired before packet received\n\r");
    } else {
      printf("%s: Unexpected alarm: %s \n\r", __FUNCTION__,
        decodeState(state));
    }
  }

  async event void Rf1aPhysical.frameStarted () { 
    if (state == S_IDLE){
      call Alarm.start(RETX_DELAY);
      state = S_WAIT_RECEIVE;
    } else if (state == S_ORIGIN_SENDING || state == S_SENDING){
      //ok, we got this because we were transmitting. 
      call Alarm.stop();
//      printf("TX Frame start (cancel)\n\r");
    } else {
      call Alarm.stop();
      printf("Unexpected Frame start: %s\n\r", decodeState(state));
    }
  }
   
  command void* Send.getPayload(message_t* msg, uint8_t len){
    return call LayerPacket.getPayload(msg, len);
  }

  command error_t Send.send(message_t* msg, uint8_t len)
  { 
    //TODO: delay this until our time frame comes up
    if (state != S_IDLE){
      return EBUSY;
    } else {
      error_t error;
//      cx_header_t* hdr = getHeader(msg);
      //stash destination 
      call CXPacket.setDestination(msg, call AMPacket.destination(msg));
      //replace with broadcast 
      call Ieee154Packet.setDestination(msg, IEEE154_BROADCAST_ADDR);
      call CXPacket.setSn(msg, mySn++);
      call CXPacket.setType(msg, CX_TYPE_DATA);
      state = S_ORIGIN_SEND_START;
      #ifdef DEBUG_FLOOD
      printf("Call subsend: %p %d\n\r", msg, len+sizeof(cx_header_t));
      printHeaders(msg);
      #endif
      error = call SubSend.send(msg, len + sizeof(cx_header_t)); 
      lastSrc = call CXPacket.source(msg);
      lastSn = call CXPacket.sn(msg);
      if (error != SUCCESS){
        printf("%s: %s\n\r", __FUNCTION__, decodeError(error));
      }
      return error;
    }
  }

  event void SubSend.sendDone(message_t* msg, error_t error){
    if (state == S_ORIGIN_SENDING){
      state = S_IDLE;
      //TODO: delay until end of flooding period
      signal Send.sendDone(msg, error);
    }else{
      state = S_IDLE;
      //done forwarding
    }
  }

  //TODO: implement me!
  command error_t CXFloodControl.setRoot(bool isRoot){return FAIL;}
  command error_t CXFloodControl.setPeriod(uint32_t period){return FAIL;}
  command error_t CXFloodControl.setFrameLen(uint32_t frameLen){return FAIL;}
  command error_t CXFloodControl.setNumFrames(uint16_t numFrames){return FAIL;}
  command error_t CXFloodControl.assignFrame(uint16_t index, am_addr_t nodeId){return FAIL;}
  command error_t CXFloodControl.freeFrame(uint16_t index){return FAIL;}
  command error_t CXFloodControl.claimFrame(uint16_t index){return FAIL;}

  //TODO: should allow cancellation as long as we haven't loaded it
  //into the TX fifo. return to idle state.
  command error_t Send.cancel(message_t* msg){return FAIL;}


  //TODO: duty cycling
  command error_t SplitControl.start(){ return call SubSplitControl.start(); }
  command error_t SplitControl.stop(){ return call SubSplitControl.stop(); }
  event void SubSplitControl.startDone(error_t error){ signal SplitControl.startDone(error); }
  event void SubSplitControl.stopDone(error_t error){ signal SplitControl.stopDone(error); }


  //flooding primitive does not offer acknowledgements, so fail anything
  //that comes at this interface.
  async command error_t PacketAcknowledgements.requestAck( message_t* msg ){ return FAIL; }
  async command error_t PacketAcknowledgements.noAck( message_t* msg){ return FAIL; }
  async command bool PacketAcknowledgements.wasAcked(message_t* msg){ return FALSE; }

  //For flooding: no CCA check, switch to FSTXON immediately after
  //receiving.
  async command bool GetCCACheck.getNow(){ return FALSE; }
  async command bool GetFastReTX.getNow(){ return TRUE; }

  command uint8_t Send.maxPayloadLength(){return call LayerPacket.maxPayloadLength();}

  //unused events from rf1aphysical interface
  async event void Rf1aPhysical.sendDone (int result) { }
  async event void Rf1aPhysical.receiveStarted (unsigned int length) { }
  async event void Rf1aPhysical.receiveDone (uint8_t* buffer,
                                             unsigned int count,
                                             int result) { }
  async event void Rf1aPhysical.receiveBufferFilled (uint8_t* buffer,
                                                     unsigned int count) { }
  async event void Rf1aPhysical.clearChannel () { }
  async event void Rf1aPhysical.carrierSense () { }
  async event void Rf1aPhysical.released () { }

}

/* 
 * Local Variables:
 * mode: c
 * End:
 */
