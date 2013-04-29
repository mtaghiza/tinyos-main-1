
 #include "CXTransportDebug.h"
module FloodBurstP {
  provides interface Send;
  provides interface Receive;
  uses interface CXRequestQueue;
  uses interface CXTransportPacket;
  uses interface Packet;
  uses interface SplitControl;
  uses interface CXPacketMetadata;
  uses interface SlotTiming;
  uses interface AMPacket;
  provides interface RequestPending;
  uses interface RoutingTable;
} implementation {
  message_t msg_internal;
  //We only own this buffer when there is no rx pending. We have no
  //guarantee that we'll get the same buffer back when the receive is
  //handled.
  message_t* rxMsg = &msg_internal;
  bool sending = FALSE;
  bool rxPending = FALSE;
  bool on = FALSE;
  uint32_t rxf = INVALID_FRAME;

  uint32_t lastTX;

  task void receiveNext(){
    if ( on && !rxPending){
      error_t error;
      rxf = call CXRequestQueue.nextFrame(FALSE);
      error = call CXRequestQueue.requestReceive(0,
        rxf, 0,
        FALSE, 0,
        0, NULL, rxMsg);
      if (error != SUCCESS){
        printf("!fb.rn: %x\r\n", error);
      }else{
        rxPending = TRUE;
      }
    }
  }

  event void SplitControl.startDone(error_t error){
    if (error == SUCCESS){
      on = TRUE;
      post receiveNext();
    } else {
      printf("!fb.sc.startDone: %x\r\n", error);
    }
  }

  event void SplitControl.stopDone(error_t error){
    if (SUCCESS == error){
      on = FALSE;
    }
  }

  command error_t Send.send(message_t* msg, uint8_t len){
    printf_TRANSPORT("FB.send\r\n");
    if (! sending){
      uint32_t nf = call CXRequestQueue.nextFrame(TRUE);
      if (call SlotTiming.framesLeftInSlot(nf) >= 
          call RoutingTable.getDistance(TOS_NODE_ID, 
            call AMPacket.destination(msg))){
        //Cool, there's enough frames left in this slot.
        uint32_t lss = call SlotTiming.lastSlotStart();

        if (nf == lss || lastTX >= lss){
          //cool, the network is set up for receiving broadcasts (this
          //is either the first frame of the slot, or we've previously
          //sent a broadcast during this slot).
        } else {
          nf = call SlotTiming.nextSlotStart(nf); 
        }
      } else {
        nf = call SlotTiming.nextSlotStart(nf);
      }

      //  this slot to deliver it.
      if (nf != INVALID_FRAME){
        //TODO: should set TTL here? (based on RoutingTable.distance)
        error_t error = call CXRequestQueue.requestSend(0,
          nf, 0,
          TXP_BROADCAST,
          FALSE, 0,
          NULL, 
          msg);
        if (error == SUCCESS){
          sending = TRUE;
        }
        return error;
      }else{
        return FAIL;
      }

    } else { 
      return ERETRY;
    }
  }

  command error_t Send.cancel(message_t* msg){
    //not supported
    return FAIL;
  }

  command uint8_t Send.maxPayloadLength(){
    return call Packet.maxPayloadLength();
  }

  command void* Send.getPayload(message_t* msg, uint8_t len){
    return call Packet.getPayload(msg, len);
  }

  event void CXRequestQueue.receiveHandled(error_t error, 
      uint8_t layerCount, 
      uint32_t atFrame, uint32_t reqFrame, 
      bool didReceive, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    if (rxPending){
      rxMsg = msg;
      rxPending = FALSE;
      if (didReceive){
        uint8_t pll = call Packet.payloadLength(msg);
//        printf("rxh %lu %lu\r\n", reqFrame, atFrame);
        rxMsg = signal Receive.receive(msg, 
          call Packet.getPayload(msg, pll),
          pll);
      }
      post receiveNext();
    } else {
      printf("!fb.rh, not rxPending\r\n");
    }
  }

  event void CXRequestQueue.sendHandled(error_t error, 
      uint8_t layerCount,
      uint32_t atFrame, uint32_t reqFrame, 
      uint32_t microRef, uint32_t t32kRef,
      void* md, message_t* msg){
    sending = FALSE;
//    printf("txh %lu %lu\r\n", reqFrame, atFrame);
    printf_TRANSPORT("fb.sd %p %x\r\n", msg, error);
    signal Send.sendDone(msg, error);
    lastTX = atFrame;
  }

  //unused events below
  event void CXRequestQueue.sleepHandled(error_t error, 
    uint8_t layerCount,
    uint32_t atFrame, uint32_t reqFrame){
  }
  event void CXRequestQueue.wakeupHandled(error_t error, 
    uint8_t layerCount, 
    uint32_t atFrame, uint32_t reqFrame){
  }

  command bool RequestPending.requestPending(uint32_t frame){
    return (frame != INVALID_FRAME) && rxPending;
  }
}
