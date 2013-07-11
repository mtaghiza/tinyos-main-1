
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
  //This goes to the body of the mac packet
  uses interface Packet;

  uses interface SlotController[uint8_t ns];
  uses interface Neighborhood;

  uses interface Send as SubSend;
  uses interface Receive as SubReceive;

  uses interface Timer<T32khz> as SlotTimer;
  uses interface Timer<T32khz> as FrameTimer;

  uses interface Pool<message_t>;
  uses interface ActiveMessageAddress;
  uses interface RoutingTable;

  provides interface CTS;
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
  uint8_t missedCTS;

  void handleCTS(message_t* msg);
  task void nextRX();
  error_t rx(uint32_t timeout, bool retx);
  error_t send(message_t* msg, uint8_t len, uint8_t ttl);
  
  uint8_t activeNS;
  event void LppControl.wokenUp(uint8_t ns){
    if (state == S_UNSYNCHED){
      activeNS = ns;
      call Neighborhood.clear();
      cinfo(SCHED, "Sched wakeup for %lu on %u\r\n", 
        call SlotController.wakeupLen[activeNS](), 
        activeNS);
      signalEnd = FALSE;
      missedCTS = 0;
      state = S_WAKEUP;
      wakeupStart = call SlotTimer.getNow();
      post nextRX();
    }else{
      cerror(SCHED, "Unexpected state for wake up %x\r\n", state);
    }
  }

  bool shouldForward(am_addr_t src, am_addr_t dest, uint8_t bw){
    am_addr_t self = call ActiveMessageAddress.amAddress();
    //When the source is the master of the network,
    //there is no bidirectional routing info. At any rate, it's
    //probably likely that the router will send messages to a variety
    //of nodes. 
    if (src == master){
      return TRUE;
    }
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

  // The behavior at the end of a CTS transmission is the same whether
  // we sent it or another node: set up the frame timer. If you are
  // the slot owner, set up a status message to send. Otherwise, wait
  // for a status message to arrive.

  void handleCTS(message_t* msg){
    master = call CXLinkPacket.source(msg);
    //If we are going to be sending data, then we need to send a
    //status back (for forwarder selection)
    if ( (call CXLinkPacket.getLinkHeader(msg))->destination == call ActiveMessageAddress.amAddress()){
      state = S_STATUS_PREP;
      call SlotController.receiveCTS[activeNS](activeNS);
      //synchronize sends to CTS timestamp
      cdbg(SCHED, "a FT.sp %lu,  %lu @ %lu\r\n",
        timestamp(msg), 
        FRAME_LENGTH, call FrameTimer.getNow());
      call FrameTimer.startPeriodicAt(timestamp(msg), FRAME_LENGTH);
      post sendStatus();
    }else{
      state = S_STATUS_WAIT_READY;
      cdbg(SCHED, "f FT.sp %lu - %lu = %lu,  %lu @ %lu\r\n",
        timestamp(msg), RX_SLACK, 
        timestamp(msg) - RX_SLACK,
        FRAME_LENGTH, 
        call FrameTimer.getNow());
      //synchronize receives to CTS timestamp - slack
      call FrameTimer.startPeriodicAt( timestamp(msg) - RX_SLACK, FRAME_LENGTH);
    }
  }

  event message_t* SubReceive.receive(message_t* msg, void* pl,
      uint8_t len){
    call RoutingTable.addMeasurement(call CXLinkPacket.source(msg), 
      call ActiveMessageAddress.amAddress(), 
      call CXLinkPacket.rxHopCount(msg));
    cdbg(SCHED, "sr.r %x\r\n", call CXMacPacket.getMacType(msg));
    switch (call CXMacPacket.getMacType(msg)){
      case CXM_CTS:
        //if this is the start of a known slot or during the wakeup
        //period, treat it the same.
        if (state == S_SLOT_CHECK || state == S_WAKEUP){
          //Set the slot/frame timing based on the master's CTS message.
          framesLeft = (SLOT_LENGTH / FRAME_LENGTH) - 1;
          call SlotTimer.startPeriodicAt(timestamp(msg) - RX_SLACK, SLOT_LENGTH);
          handleCTS(msg);
        } else {
          cerror(SCHED, "Unexpected state %x for rx(cts)\r\n", 
            state);
        }
        return msg;

      case CXM_STATUS:
        {
          cx_status_t* status = (cx_status_t*) (call Packet.getPayload(msg, sizeof(cx_status_t)));
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
          return call SlotController.receiveStatus[activeNS](msg, status);
        }

      case CXM_EOS:
        return call SlotController.receiveEOS[activeNS](msg, 
          call Packet.getPayload(msg, sizeof(cx_eos_t)));

      case CXM_DATA:
        return signal Receive.receive(msg, 
          call Packet.getPayload(msg, call Packet.payloadLength(msg)), 
          call Packet.payloadLength(msg));

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
      pl = call Packet.getPayload(statusMsg, sizeof(cx_status_t));
      call Packet.clear(statusMsg);
      call CXMacPacket.setMacType(statusMsg, CXM_STATUS);
      call CXLinkPacket.setDestination(statusMsg, master);

      //future: adjust bw depending on how much uncertainty we
      //observe.
      pl -> bw = call SlotController.bw[activeNS]();
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
      cdbg(SCHED, "FTP %x %x %x\r\n", pendingRX, pendingTX, state);
      //ok. we are still in the process of receiving/forwarding a
      //packet, it appears.
      //pass
    } else if (framesLeft <= 1){
      //TODO: framesLeft should be 0 or 1?
      switch(state){
        //We can be in any of these three states when the last frame
        //starts.
        case S_UNUSED_SLOT:
          //maybe a node added data mid-slot (so it originally
          //reported none pending)
        case S_ACTIVE_SLOT:
          //node had data
        case S_STATUS_WAIT:
          //no status packet received (maybe lost)
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
              call CXMacPacket.setMacType(eosMsg, CXM_EOS);
              pl -> dataPending = (pendingMsg == NULL)?FALSE:TRUE;
              call CXLinkPacket.setDestination(eosMsg, master);
            }
          }
          //fall through
        case S_SLOT_END_READY:
          {
            error_t error = send(eosMsg, sizeof(cx_eos_t), 
              call SlotController.maxDepth[activeNS]());
            if (error == SUCCESS){
              cdbg(SCHED, "SES\r\n");
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
      cdbg(SCHED, "FTN %x\r\n", state);
      switch (state){
        case S_STATUS_READY:
          {
            error_t error = send(statusMsg, sizeof(cx_status_t), 
              call SlotController.maxDepth[activeNS]());
            if (error == SUCCESS){
              state = S_STATUS_SENDING;
            }else{
              cerror(SCHED, "FT %x: SS.S %x\r\n", state, error);
            }
          }
          break;

        case S_STATUS_WAIT:
          framesWaited ++;
          if (framesWaited > call SlotController.maxDepth[activeNS]()){
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
                + call SlotController.bw[activeNS]()
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
      + call SlotController.bw[activeNS]();
  }

  command error_t Send.send(message_t* msg, uint8_t len){
    if (pendingMsg != NULL){
      return EBUSY;
    } else {
      printf("SS.s %x\r\n", state);
      if (state == S_STATUS_PREP || state == S_IDLE){ 
        pendingMsg = msg;
        pendingLen = len;
        if (state == S_IDLE){
          cdbg(SCHED_CHECKED, "fl %u ct %u d(%u, %u) %u bw %u:",
            framesLeft, clearTime(msg),
            call CXLinkPacket.source(msg),
            call CXLinkPacket.destination(msg),
            call RoutingTable.getDistance( 
              call CXLinkPacket.source(msg),
              call CXLinkPacket.destination(msg)),
            call SlotController.bw[activeNS]());
          //need to leave 1 frame for EOS message
          if (framesLeft <= clearTime(msg) + 1){
            pendingMsg = NULL;
            cdbg(SCHED, "end\r\n");
            state = S_SLOT_END_PREP;
            //Not enough space to send: so, clear it out and tell
            //upper layer to retry.
            return ERETRY;
          }else{
            cdbg(SCHED, "continue\r\n");
            state = S_DATA_READY;
          }
        }
        return SUCCESS;
      }else {
        //We don't yet have clearance to send, tell upper layer to
        //try again some time.
        return ERETRY;
      }
    }
  }

  error_t send(message_t* msg, uint8_t len, uint8_t ttl){
    if (pendingTX){
      return EBUSY;
    } else {
      error_t error;
      call CXLinkPacket.setTtl(msg, ttl);
      call Packet.setPayloadLength(msg, len);
      error = call SubSend.send(msg, len);
      if (error == SUCCESS){
        pendingTX = TRUE;
      }else{
        cerror(SCHED, "SS.S %x\r\n", error);
      }
      return error;
    }
  }

  event void SubSend.sendDone(message_t* msg, error_t error){
    pendingTX = FALSE;
    if (state == S_STATUS_SENDING){
      if (msg == statusMsg){
        cx_status_t* pl = call Packet.getPayload(msg,
          sizeof(cx_status_t));
        if (error == SUCCESS){
          if (pl -> dataPending && pendingMsg != NULL){
            state = S_DATA_READY;
          }else{
            //No data pending: so we sleep until the next slot start.
            call FrameTimer.stop();
            call CXLink.sleep();
            state = S_UNUSED_SLOT;
          }
        }
        call Pool.put(call SlotController.receiveStatus[activeNS](statusMsg, pl));
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
      framesLeft = (SLOT_LENGTH/FRAME_LENGTH) - 1;
      call SlotTimer.startPeriodicAt(timestamp(msg), SLOT_LENGTH);

      handleCTS(ctsMsg);
      call Pool.put(ctsMsg);
      ctsMsg = NULL;

    } else if (state == S_SLOT_END_SENDING){
      cx_eos_t* pl = call Packet.getPayload(msg,
        sizeof(cx_eos_t));
      call Pool.put(call SlotController.receiveEOS[activeNS](eosMsg, pl));
      eosMsg = NULL;
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
      error_t error = call CXLink.rx(timeout, retx);
      if (error == SUCCESS){
        pendingRX = TRUE;
      }
      return error;
    }
  }

  bool wakeupTimeoutStillGoing(uint32_t t){
    return (t - wakeupStart) 
      < call SlotController.wakeupLen[activeNS]();
  }
  
  uint32_t slowToFast(uint32_t slowTicks){
    return slowTicks * (FRAMELEN_FAST_NORMAL/FRAMELEN_SLOW);
  }

  task void nextRX(){
    cdbg(SCHED_CHECKED, "next RX ");
    if (state == S_WAKEUP){
      uint32_t t = call SlotTimer.getNow();
      cdbg(SCHED_CHECKED, "wakeup\r\n");
      if (wakeupTimeoutStillGoing(t)){
        // - allow rest of network to wake up
        // - add 1 slow frame for the first CTS to go down
        uint32_t remainingTime = slowToFast(
            call SlotController.wakeupLen[activeNS]() - (t - wakeupStart) + FRAMELEN_SLOW);
        error_t error;
        cdbg(SCHED_CHECKED, "rx for %lu / %lu (%lu)\r\n", 
          remainingTime, 
          call SlotController.wakeupLen[activeNS](),
          slowToFast(call SlotController.wakeupLen[activeNS]()));
        error = rx(remainingTime, TRUE);
        if (error != SUCCESS){
          cwarn(SCHED, "wakeup re-rx: %x\r\n", error);
        }
      } else {
        cdbg(SCHED_CHECKED, "Done waking\r\n");
        if (call SlotController.isMaster[activeNS]()){
          signal SlotTimer.fired();
        } else {
          //TODO: this should be one probe interval
          rx(RX_TIMEOUT_MAX, TRUE);
          state = S_SLOT_CHECK;
        }
      }
    }else if (state == S_SLOT_CHECK){
      missedCTS++;
      cdbg(SCHED, "No CTS\r\n");
      if (missedCTS < MISSED_CTS_THRESH){
        cdbg(SCHED, "Sleep this slot\r\n");
        call FrameTimer.stop();
        call CXLink.sleep();
        state = S_UNUSED_SLOT;
      }else {
        //CTS limit exceeded, back to sleep
        error_t error = call LppControl.sleep();
        cdbg(SCHED, "Back to sleep.\r\n");
        call SlotTimer.stop();
        call FrameTimer.stop();
        if (error == SUCCESS){
          state = S_UNSYNCHED;
        }else{
          //awjeez awjeez
          cerror(SCHED, "No CTS, failed to sleep with %x\r\n", error);
        }
      }
    }else{
      //ignore next rx (e.g. handled at frametimer.fired)
      cdbg(SCHED, "nrxi %x\r\n", state);
    }
  }
  
  //when slot timer fires, master will send CTS, and slave will try to
  //check for it.
  event void SlotTimer.fired(){
    framesLeft = SLOT_LENGTH/FRAME_LENGTH;
    if (signalEnd){
      call SlotController.endSlot[activeNS]();
      signalEnd = FALSE;
    }
    if (call SlotController.isMaster[activeNS]()){
      if(call SlotController.isActive[activeNS]()){
        am_addr_t activeNode = call
        SlotController.activeNode[activeNS]();
        cdbg(SCHED, "master + active: next %x\r\n", activeNode);
        signalEnd = TRUE;
        if (ctsMsg == NULL){
          ctsMsg = call Pool.get();
          if (ctsMsg == NULL){
            cerror(SCHED, "No msg in pool for cts\r\n");
          } else {
            error_t error;
//            cx_lpp_cts_t* pl = call Packet.getPayload(ctsMsg,
//              sizeof(cx_lpp_cts_t));
            call Packet.clear(ctsMsg);
            call CXMacPacket.setMacType(ctsMsg, CXM_CTS);
//            pl -> addr = activeNode;
            call CXLinkPacket.setDestination(ctsMsg, activeNode);
            //header only
            error = send(ctsMsg, 0,
              call SlotController.maxDepth[activeNS]());
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
        cdbg(SCHED, "End of active\r\n");
        //end of active period: can sleep now.
        call LppControl.sleep();
        call SlotTimer.stop();
        call FrameTimer.stop();
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

  command void* Send.getPayload(message_t* msg, uint8_t len){
    return call Packet.getPayload(msg, len);
  }
  command uint8_t Send.maxPayloadLength(){
    return call Packet.maxPayloadLength();
  }

  command error_t Send.cancel(message_t* msg){
    //The only times that we can have a cancelable message now are:
    // 
    //1. between (a) getting a CTS and providing a packet
    //   to send and (b) preparing the corresponding status message
    //   indicating that there is a packet to transmit
    //2. Between sending a packet in a stream and that packet actually
    //   being sent (1 frame-length, max)
    //
    //Since it's so constrained, and since the AM queuing layer
    //provides cancellation support, we don't allow it here.
    return FAIL;
  }

  async event void ActiveMessageAddress.changed(){ }

  default command am_addr_t SlotController.activeNode[uint8_t ns](){
    return AM_BROADCAST_ADDR;
  }
  default command bool SlotController.isMaster[uint8_t ns](){
    return FALSE;
  }
  default command bool SlotController.isActive[uint8_t ns](){
    return FALSE;
  }
  default command uint8_t SlotController.bw[uint8_t ns](){
    return 0;
  }
  default command uint8_t SlotController.maxDepth[uint8_t ns](){
    return 0;
  }
  default command message_t* SlotController.receiveEOS[uint8_t ns](message_t* msg,
  cx_eos_t* pl){
    return msg;
  }
  default command message_t* SlotController.receiveStatus[uint8_t ns](message_t*
  msg, cx_status_t* pl){
    return msg;
  }
  default command void SlotController.receiveCTS[uint8_t ns](uint8_t ans){}
  default command void SlotController.endSlot[uint8_t ns](){}
  default command uint32_t SlotController.wakeupLen[uint8_t ns](){
    return 0;
  }

}
