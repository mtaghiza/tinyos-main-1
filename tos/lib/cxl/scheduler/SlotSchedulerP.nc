
 #include "CXScheduleDebug.h"
 #include "CXSchedule.h"
 #include "CXMac.h"
module SlotSchedulerP {
  provides interface Send;
  provides interface Receive;

  uses interface CXLink;
  uses interface LppControl;
  uses interface CXMacPacket;
  uses interface CXLinkPacket;
  uses interface Packet;

  uses interface SlotController;
  uses interface Neighborhood;

  uses interface Send as SubSend;
  uses interface Receive as SubReceive;

  uses interface Timer<T32khz> as SlotTimer;
  uses interface Timer<T32khz> as FrameTimer;

  uses interface Pool<message_t>;
  uses interface ActiveMessageAddress;
  uses interface RoutingTable;
} implementation {

  enum {
    //no idea when we're going to get woken up. transition out at
    //LppControl.wokenUp.
    S_UNSYNCHED = 0x00,

    //Just woken up: should be RX'ing with retx until the wakeup
    //period has ended.
    S_WAKEUP = 0x01,

    //slot timer has fired, we're waiting to see a CTS to give us the
    //real slot/frame time reference.
    S_SLOT_CHECK = 0x02,
    
    //we've received a CTS, but we haven't gotten our response ready
    //yet.
    S_STATUS_PREP = 0x03,
    //We have been given a CTS and have the response ready to go.
    S_STATUS_READY = 0x04,
    //We are waiting for the response to clear.
    S_STATUS_SENDING = 0x05,
    
    //we have a packet queued and will send it at the next
    //opportunity.
    S_DATA_READY = 0x06,
    //data being sent, waiting for it to clear.
    S_DATA_SENDING = 0x07,
    //available to send more data, but none queued up at the moment.
    S_IDLE = 0x08, 
    
    //fixing to prepare the EOS message
    S_SLOT_END_PREP = 0x09,
    //done with everything we're going to do this slot, waiting for
    //the last frame so we can send EOM/data pending packet.
    S_SLOT_END_READY = 0x0a,
    S_SLOT_END_SENDING = 0x0b,
    
    //got the cts, will start checking at the next frame start.
    S_STATUS_WAIT_READY = 0x10,
    //waiting for the status to come in.
    S_STATUS_WAIT = 0x11,
    
    //general catch-all for behavior in last frame (waiting for final
    //EOS to come in)
    S_SLOT_END = 0x12,
    
    //CTS send is in progress
    S_CTS_SENDING = 0x20,

    //this slot is in use, and we are a forwarder. 
    S_ACTIVE_SLOT = 0xFE,
    //No data pending from ourselves, and we are either not in
    //forwarder set or no response to CTS was observed (and so, there
    //is no data coming during this slot).
    S_UNUSED_SLOT = 0xFF,
  };

  uint8_t state = S_UNSYNCHED;
  

  message_t* pendingMsg;
  uint8_t pendingLen;
  message_t* statusMsg;
  message_t* ctsMsg;
  message_t* eosMsg;

  bool pendingRX = FALSE;
  bool pendingTX = FALSE;
  
  //deal with fencepost issues w.r.t signalling end of last
  //slot/beginning of next slot.
  bool signalEnd;

  uint32_t wakeupStart;
  uint8_t framesLeft;
  uint8_t framesWaited;
  am_addr_t master;

  task void nextRX();
  error_t rx(uint32_t timeout, bool retx);
  error_t send(message_t* msg, uint8_t len, uint8_t ttl);

  event void LppControl.wokenUp(){
    if (state == S_UNSYNCHED){
      signalEnd = TRUE;
      state = S_WAKEUP;
      wakeupStart = call SlotTimer.getNow();
      post nextRX();
    }else{
      cerror(SCHED, "Unexpected state for wake up %x\r\n", state);
    }
  }

  bool shouldForward(am_addr_t src, am_addr_t dest, uint8_t bw){
    am_addr_t self = call ActiveMessageAddress.amAddress();

    if (call RoutingTable.getDistance(src, self) + call RoutingTable.getDistance(self, dest) 
        <= call RoutingTable.getDistance(src, dest) + bw){
      return TRUE;
    }else{
      return FALSE;
    }
    
  }

  uint32_t timestamp(message_t* msg){
    return (call CXLinkPacket.getLinkMetadata(msg))->time32k;
  }

  task void sendStatus();

  event message_t* SubReceive.receive(message_t* msg, void* pl,
      uint8_t len){
    call RoutingTable.addMeasurement(call CXLinkPacket.source(msg), 
      call ActiveMessageAddress.amAddress(), 
      call CXLinkPacket.rxHopCount(msg));
    switch (call CXMacPacket.getMacType(msg)){
      case CXM_CTS:
        if (state == S_SLOT_CHECK){
          //Set the slot/frame timing based on the master's CTS message.
          framesLeft = SLOT_LENGTH / FRAME_LENGTH;
          call SlotTimer.startPeriodicAt(timestamp(msg) - RX_SLACK, SLOT_LENGTH);
          //If we are going to be sending data, then we need to send a
          //status back (for forwarder selection)
          if ( (call CXLinkPacket.getLinkHeader(msg))->destination == call ActiveMessageAddress.amAddress()){
            //synchronize sends to CTS timestamp
            call FrameTimer.startPeriodicAt(timestamp(msg), FRAME_LENGTH);
            master = call CXLinkPacket.source(msg);
            state = S_STATUS_PREP;
            post sendStatus();
          }else{
            //synchronize receives to CTS timestamp - slack
            state = S_STATUS_WAIT_READY;
            call FrameTimer.startPeriodicAt(timestamp(msg) - RX_SLACK, FRAME_LENGTH);
          }
        } else {
          cerror(SCHED, "Unexpected state %x for rx(cts)\r\n", 
            state);
        }
        return msg;

      case CXM_STATUS:
        {
          cx_status_t* status = (cx_status_t*) pl;
          call RoutingTable.addMeasurement(
            call CXLinkPacket.destination(msg),
            call CXLinkPacket.source(msg), 
            status->distance);
  
          if (status->dataPending && shouldForward(call CXLinkPacket.source(msg), 
              call CXLinkPacket.destination(msg), status->bw)){
            state = S_ACTIVE_SLOT;
          } else {
            error_t error = call CXLink.sleep();
            call FrameTimer.stop();
            if (error != SUCCESS){
              cerror(SCHED, "no fwd sleep %x\r\n", error);
            }
            state = S_UNUSED_SLOT;
          }
          return call SlotController.receiveStatus(msg, pl);
        }

      case CXM_EOS:
        return call SlotController.receiveEOS(msg, pl);

      case CXM_DATA:
        return signal Receive.receive(msg, pl, len);

      default:
        cerror(SCHED, "unexpected CXM %x\r\n", 
          call CXMacPacket.getMacType(msg));
        return msg;
    }
  }

  task void sendStatus(){
    if (statusMsg == NULL){
      cx_status_t* pl;
      statusMsg = call Pool.get();
      pl = call Send.getPayload(statusMsg, sizeof(cx_status_t));
      call Packet.clear(statusMsg);
      call CXMacPacket.setMacType(statusMsg, CXM_STATUS);
      call CXLinkPacket.setDestination(statusMsg, master);

      //future: adjust bw depending on how much uncertainty we
      //observe.
      pl -> bw = call SlotController.bw();
      pl -> distance = call RoutingTable.getDistance(master, 
        call ActiveMessageAddress.amAddress());
      call Neighborhood.copyNeighborhood(pl->neighbors);
      //indicate whether there is any data to be sent.
      pl -> dataPending = (pendingMsg != NULL);
      state = S_STATUS_READY;
      //great. when we get the next FrameTimer.fired, we'll send it
      //out.
    }else{
      cerror(SCHED, "Status msg not free\r\n");
    }
  }

  event void FrameTimer.fired(){
    framesLeft --;
    if (pendingRX || pendingTX){
      //ok. we are still in the process of receiving/forwarding a
      //packet, it appears.
      //pass
    } else if (framesLeft >= 1){
      //TODO: framesLeft should be 0 or 1?
      switch(state){
        case S_UNUSED_SLOT:
        case S_ACTIVE_SLOT:
          {
            //on last frame: wait around for an
            //  end-of-message/data-pending from the owner
            error_t error = rx(CTS_TIMEOUT, TRUE);
            if (error != SUCCESS){
              cerror(SCHED, "FT %x: rx %x\r\n", state, error);
            }else {
              state = S_SLOT_END;
            }
          }
          break;

        case S_IDLE:
          //fall through
        case S_SLOT_END_PREP:
          if (eosMsg == NULL){
            eosMsg = call Pool.get();
            if (eosMsg == NULL){
              cerror(SCHED, "No EOS in pool\r\n");
              state = S_ACTIVE_SLOT;
              return;
            }else{
              cx_eos_t* pl = call Packet.getPayload(eosMsg,
                sizeof(cx_eos_t));
              call Packet.clear(eosMsg);
              pl -> dataPending = (pendingMsg != NULL);
              call CXLinkPacket.setDestination(eosMsg, master);
            }
          }
          //fall through
        case S_SLOT_END_READY:
          {
            error_t error = send(eosMsg, sizeof(cx_eos_t), 
              call SlotController.maxDepth());
            if (error == SUCCESS){
              state = S_SLOT_END_SENDING;
            }else{ 
              cerror(SCHED, "ft.f %x %x fl 1\r\n", state, error);
            }
          }
          break;

        default:
          cerror(SCHED, "Unexpected state %x with fl 1\r\n", state);
          break;
      }
      call FrameTimer.stop();

    } else {
      switch (state){
        case S_STATUS_READY:
          {
            error_t error = send(statusMsg, sizeof(cx_status_t), 
              call SlotController.maxDepth());
            if (error == SUCCESS){
              state = S_STATUS_SENDING;
            }else{
              cerror(SCHED, "FT %x: SS.S %x\r\n", state, error);
            }
          }
          break;

        case S_STATUS_WAIT:
          framesWaited ++;
          if (framesWaited >= call SlotController.maxDepth() + 1){
            error_t error = call CXLink.sleep();
            if (error == SUCCESS){
              call FrameTimer.stop();
              state = S_UNUSED_SLOT;
            } else {
              cerror(SCHED, "Status timeout, sleep failed %x\r\n",
                error);
            }
            return;
          }
          //fall-through
        case S_STATUS_WAIT_READY:
          {
            error_t error = rx(DATA_TIMEOUT, TRUE);
            if (error != SUCCESS){
              cerror(SCHED, "FT %x: rx %x\r\n", state, error);
            }else{
              if (state == S_STATUS_WAIT_READY){
                state = S_STATUS_WAIT;
                framesWaited = 0;
              }
            }
          }
          break;
  
        case S_DATA_READY:
          { 
            error_t error = send(pendingMsg, 
              pendingLen, 
              call RoutingTable.getDistance(
                call ActiveMessageAddress.amAddress(), 
                call CXLinkPacket.destination(pendingMsg))
                + call SlotController.bw()
              );
            if (error == SUCCESS){
              state = S_DATA_SENDING;
            }else{
              cerror(SCHED, "FT %x: SS.S %x\r\n", state, error);
            }
          }
          break;

        case S_ACTIVE_SLOT:
          {
            error_t error = rx(DATA_TIMEOUT, TRUE);
            if (error != SUCCESS){
              cerror(SCHED, "FT %x: rx %x\r\n", state, error);
            }
          }
          break;

        default:
          break;
      }
    }
  }

  uint8_t clearTime(message_t* msg){
    return call RoutingTable.getDistance(
      call CXLinkPacket.source(msg),
      call CXLinkPacket.destination(msg)) 
      + call SlotController.bw();
  }

  command error_t Send.send(message_t* msg, uint8_t len){
    if (pendingMsg != NULL){
      return EBUSY;
    } else {
      pendingMsg = msg;
      pendingLen = len;
      if (state == S_IDLE){
        if (framesLeft <= clearTime(msg)){
          state = S_SLOT_END_PREP;
        }else{
          state = S_DATA_READY;
        }
      }
      return SUCCESS;
    }
  }

  error_t send(message_t* msg, uint8_t len, uint8_t ttl){
    if (pendingTX){
      return EBUSY;
    } else {
      error_t error;
      call CXLinkPacket.setTtl(msg, ttl);
      error = call SubSend.send(msg, len);
      if (error == SUCCESS){
        pendingTX = TRUE;
      }
      return error;
    }
  }

  event void SubSend.sendDone(message_t* msg, error_t error){
    pendingTX = FALSE;
    if (state == S_STATUS_SENDING){
      if (msg == statusMsg){
        if (error == SUCCESS){
          cx_status_t* pl = call Send.getPayload(msg,
            sizeof(cx_status_t));
          if (pl -> dataPending && pendingMsg != NULL){
            state = S_DATA_READY;
          }else{
            //No data pending: so we sleep until the next slot start.
            call FrameTimer.stop();
            call CXLink.sleep();
            state = S_UNUSED_SLOT;
          }
        }
        call Pool.put(statusMsg);
        statusMsg = NULL;
      } else {
        cerror(SCHED, "Unexpected sendDone, status msg %p got %p\r\n",
          statusMsg, msg);
      }
    }else if (state == S_DATA_SENDING){
      if (framesLeft <= clearTime(msg)){
        state = S_SLOT_END_PREP;
      }else{
        state = S_IDLE;
      }
      pendingMsg = NULL;
      signal Send.sendDone(msg, error);
    } else if (state == S_CTS_SENDING){
      //master starts frame duty cycle based on CTS transmission
      call FrameTimer.startPeriodicAt(timestamp(msg) - RX_SLACK, FRAME_LENGTH);
      //start waiting for the status packet to come back.
      state = S_STATUS_WAIT_READY;
    } else if (state == S_SLOT_END_SENDING){
      call Pool.put(eosMsg);
      state = S_SLOT_END;
    } else {
      cerror(SCHED, "Unexpected send done state %x\r\n", state);
    }
  }


  event void CXLink.rxDone(){
    pendingRX = FALSE;
    post nextRX();
  }

  error_t rx(uint32_t timeout, bool retx){
    if (pendingRX){
      cerror(SCHED, "RX while pending\r\n");
      return EBUSY;
    } else {
      error_t error = rx(timeout, retx);
      if (error == SUCCESS){
        pendingRX = TRUE;
      }
      return error;
    }
  }

  bool wakeupTimeoutStillGoing(){
    //TODO: fill em in
    return TRUE;
  }

  task void nextRX(){
    if (state == S_WAKEUP){
      if (wakeupTimeoutStillGoing()){
        //TODO: set timeout to be from now until end of active period
        //wakeup.
        error_t error = rx(RX_TIMEOUT_MAX, TRUE);
        if (error != SUCCESS){
          cwarn(SCHED, "wakeup re-rx: %x\r\n", error);
        }
      } else {
        if (call SlotController.isMaster()){
          call SlotTimer.startPeriodic(SLOT_LENGTH);
          signal SlotTimer.fired();
        } else {
          //TODO: this should be one probe interval
          rx(RX_TIMEOUT_MAX, TRUE);
          state = S_SLOT_CHECK;
        }
      }
    }else if (state == S_SLOT_CHECK){
      //we didn't get a CTS, so we deem the active period over.
      //TODO safer: count up the number of non-CTS-bearing slots and
      //sleep when we've exceeded a few of them. N.B. each of these
      //timeout slots adds 30 ms of on-time (not too shabby!).
      error_t error = call LppControl.sleep();
      if (error == SUCCESS){
        state = S_UNSYNCHED;
      }else{
        //awjeez awjeez
        cerror(SCHED, "No CTS, failed to sleep with %x\r\n", error);
      }
    }
  }
  
  //when slot timer fires, master will send CTS, and slave will try to
  //check for it.
  event void SlotTimer.fired(){
    if (signalEnd){
      call SlotController.endSlot();
      signalEnd = FALSE;
    }
    if (call SlotController.isMaster()){
      if(call SlotController.isActive()){
        am_addr_t activeNode = call SlotController.activeNode();
        signalEnd = TRUE;
        if (ctsMsg == NULL){
          ctsMsg = call Pool.get();
          if (ctsMsg == NULL){
            cerror(SCHED, "No msg in pool for cts\r\n");
          } else {
            error_t error;
            cx_lpp_cts_t* pl = call Packet.getPayload(ctsMsg,
              sizeof(cx_lpp_cts_t));
            call Packet.clear(ctsMsg);
            pl -> addr = activeNode;
            call CXLinkPacket.setDestination(ctsMsg, activeNode);

            error = send(ctsMsg, 
              sizeof(cx_lpp_cts_t),
              call SlotController.maxDepth());
            if (error == SUCCESS){
              state = S_CTS_SENDING;
            }else{
              cerror(SCHED, "Failed to send cts %x\r\n", error);
              call Pool.put(ctsMsg);
            }
          }
        } else {
          cerror(SCHED, "CTS msg not available.\r\n");
        }
      } else {
        //end of active period: can sleep now.
        call LppControl.sleep();
        call SlotTimer.stop();
      }
    } else {
      error_t error = rx(CTS_TIMEOUT, TRUE);
      if (error == SUCCESS){
        state = S_SLOT_CHECK;
      }else{
        cerror(SCHED, "Failed to listen for CTS %x\r\n", error);
        state = S_UNUSED_SLOT;
      }
    }
  }

  event void LppControl.fellAsleep(){
    state = S_UNSYNCHED;
  }
  
  default command am_addr_t SlotController.activeNode(){
    return AM_BROADCAST_ADDR;
  }

  default command bool SlotController.isMaster(){
    return FALSE;
  }
  default command bool SlotController.isActive(){
    return FALSE;
  }
  default command uint8_t SlotController.bw(){
    return CX_DEFAULT_BW;
  }
  default command uint8_t SlotController.maxDepth(){
    return CX_MAX_DEPTH;
  }

  default command message_t* SlotController.receiveEOS(
      message_t* msg, void* pl){
    return msg;
  }
  default command message_t* SlotController.receiveStatus(
      message_t* msg, void *pl){
    return msg;
  }
  default command void SlotController.endSlot(){
  }

  command void* Send.getPayload(message_t* msg, uint8_t len){
    //TODO: header math
    return NULL;
  }
  command uint8_t Send.maxPayloadLength(){
    //TODO: header math
    return 0;
  }
  command error_t Send.cancel(message_t* msg){
    //TODO: ok to cancel it if we haven't reported a data
    //pending/haven't started sending it.
    return FAIL;
  }

  async event void ActiveMessageAddress.changed(){ }

}
