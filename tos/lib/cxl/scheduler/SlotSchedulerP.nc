/*
 * Copyright (c) 2014 Johns Hopkins University.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
*/


 #include "CXScheduleDebug.h"
 #include "CXSchedule.h"
 #include "CXMac.h"
 #include "CXRoutingDebug.h"
 //for sample interval in status message
 #include "ToastSampler.h"
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
  uses interface LocalTime<TMilli>;


  uses interface Pool<message_t>;
  uses interface ActiveMessageAddress;
  uses interface RoutingTable;

  provides interface CTS;

  uses interface Get<uint16_t> as RebootCounter;

  uses interface Get<probe_schedule_t*> as ProbeSchedule;
  uses interface StateDump;

  uses interface StatsLog;

  provides interface DownloadNotify[uint8_t ns];

  uses interface Get<uint32_t> as PushCookie;
  uses interface Get<uint32_t> as WriteCookie;
  uses interface Get<uint32_t> as MissingLength;
  uses interface SettingsStorage;
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

  enum {
    ROLE_UNKNOWN = 0,
    ROLE_OWNER = 1,
    ROLE_FORWARDER = 2,
    ROLE_NONFORWARDER =3,
    ROLE_WAKEUP = 4,
    ROLE_IDLE = 5,
    ROLE_NO_CTS = 6,
  };
  uint8_t slotRole;

  uint8_t state = S_UNSYNCHED;
  

  message_t* pendingMsg;
  uint8_t pendingLen;
  bool explicitDataPending;
  message_t* statusMsg;
  message_t* ctsMsg;
  message_t* eosMsg;

  bool pendingRX = FALSE;
  bool pendingTX = FALSE;
  
  //deal with fencepost issues w.r.t signalling end of last
  //slot/beginning of next slot.
  bool signalEnd;

  uint32_t wakeupStart;
  uint32_t wakeupStartMilli;
  uint8_t framesLeft;
  uint8_t framesWaited;
  am_addr_t master;
  uint8_t missedCTS;
 
  int16_t slotNum;
  uint16_t ctsSN;
  bool ctsReceived;

  void logReception(message_t* msg);
  void logTransmission(message_t* msg);

  #ifndef LOG_CTS_TIME
  #define LOG_CTS_TIME 0
  #endif

  #ifndef LOG_NEIGHBORHOOD
  #define LOG_NEIGHBORHOOD 0
  #endif

  uint32_t baseCTS;
  uint32_t rxStart;
  uint32_t rxTime;
  uint32_t lastTimer;
  uint32_t lastFired;
  uint32_t rxEnd;
  #if LOG_CTS_TIME == 1
  #warning logging CTS timing!
  uint32_t ctsStart;
  #else
  #endif

  #ifndef WRX_LIMIT
  #define WRX_LIMIT 100
  #endif
  error_t endActive();
  void handleCTS(message_t* msg);
  task void nextRX();
  error_t rx(uint32_t timeout, bool retx);
  error_t send(message_t* msg, uint8_t len, uint8_t ttl, 
    uint32_t txTime);

  uint32_t slowToFast(uint32_t slowTicks){
    return slowTicks * (FRAMELEN_FAST_NORMAL/FRAMELEN_SLOW);
  }
  
  
  uint8_t activeNS;
  uint8_t wrxCount;

  uint32_t wakeupLen(){
    return ((call ProbeSchedule.get())->wakeupLen[activeNS]);
  }

  void logStats();
  uint16_t wakeupNum;
  event void LppControl.wokenUp(uint8_t ns){
    if (state == S_UNSYNCHED){
      wakeupNum++;
      activeNS = ns;
      call Neighborhood.clear();
      signalEnd = FALSE;
      missedCTS = 0;
      state = S_WAKEUP;
      wakeupStart = call SlotTimer.getNow();
      wakeupStartMilli = call LocalTime.get();
      slotNum = -1;
      slotRole = ROLE_IDLE;
      logStats();
      slotRole = ROLE_WAKEUP;
      slotNum = 0;
      cdbg(SCHED, "Sched wakeup for %lu on %u\r\n", 
        wakeupLen(),
        activeNS);
      call RoutingTable.setDefault((call ProbeSchedule.get())->maxDepth[activeNS]);
      baseCTS = 0;
      cinfo(SCHED, "WU %u %u %lu %lu\r\n", 
        activeNS, 
        (call ProbeSchedule.get())->channel[activeNS],
        DATA_TIMEOUT,
        wakeupLen());
      cflushdbg(SCHED);
      wrxCount = 0;
      signal DownloadNotify.downloadStarted[activeNS]();
      post nextRX();
    }else{
      cerror(SCHED, "US0 %x\r\n", state);
    }
  }

  bool shouldForward(am_addr_t src, am_addr_t dest, uint8_t bw){
    #if ENABLE_FORWARDER_SELECTION == 0
    #warning Forwarder selection disabled!
    return TRUE;
    #else
    am_addr_t self = call ActiveMessageAddress.amAddress();
    uint8_t si = call RoutingTable.getDistance(src, self);
    uint8_t id = call RoutingTable.getDistance(self, dest);
    uint8_t sd = call RoutingTable.getDistance(src, dest);
    
//    //replace unknown distances with 0.
//    si = (si == call RoutingTable.getDefault())? 0 : si;
//    id = (id == call RoutingTable.getDefault())? 0 : id;
//    sd = (sd == call RoutingTable.getDefault())? 0 : sd;

    //When the source is the master of the network,
    //there is no bidirectional routing info. At any rate, it's
    //probably likely that the router will send messages to a variety
    //of nodes. 
    if (src == master){
      return TRUE;
    }
    cinfo(ROUTING, "SF %u %u %u %u %u %u %x\r\n",
      src, dest,
      si, id, sd, bw, (si + id <= sd + bw));
    return (si + id <= sd + bw);    
    #endif
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
    cx_lpp_cts_t* pl = call Packet.getPayload(msg,
      sizeof(cx_lpp_cts_t));
    slotNum = pl->slotNum;
    ctsSN = call CXLinkPacket.getSn(msg);
    ctsReceived = TRUE;
    master = call CXLinkPacket.source(msg);
    missedCTS = 0;
    if (master ==(call CXLinkPacket.getLinkHeader(msg))->destination){
      baseCTS = timestamp(msg);
    }else if (baseCTS == 0){
      cwarn(SCHED, "BBCTS\r\n");
      baseCTS = timestamp(msg);
    }
    #if LOG_CTS_TIME == 1
    cdbg(SCHED, "C %lu %lu\r\n", ctsStart-baseCTS, timestamp(msg)-baseCTS);
    if (ctsStart > timestamp(msg)){
      cdbg(SCHED, "TS\r\n");
      call StateDump.requestDump();
    }
    #endif
    //If we are going to be sending data, then we need to send a
    //status back (for forwarder selection)
    if ( (call CXLinkPacket.getLinkHeader(msg))->destination == call ActiveMessageAddress.amAddress()){
      //TODO: this should either be computed based on times (which is
      //a little fuzzy) or it should be determined based on the
      //required propagation time of a short-packet flood.
      uint8_t framesElapsed = 5;
      slotRole = ROLE_OWNER;
      //Cts, Own
      cdbg(SCHED, "C O %u %u %lu %u\r\n", 
        slotNum,
        (call CXLinkPacket.getLinkHeader(msg))->destination,
        timestamp(msg) - baseCTS, 
        call CXLinkPacket.rxHopCount(msg));
      state = S_STATUS_PREP;
      explicitDataPending = FALSE;
      call SlotController.receiveCTS[activeNS](master, activeNS);
      //synchronize sends to CTS timestamp
      cdbg(SCHED_CHECKED, "a FT.sp %lu,  %lu @ %lu\r\n",
        timestamp(msg), 
        FRAME_LENGTH, call FrameTimer.getNow());
      call FrameTimer.startOneShotAt(timestamp(msg) - TX_SLACK,
        FRAME_LENGTH * framesElapsed);
//      call FrameTimer.startPeriodicAt(timestamp(msg) - TX_SLACK, FRAME_LENGTH);
      post sendStatus();
    }else{
      //TODO: see above
      uint8_t framesElapsed = 5;
      //Cts, Else
      cdbg(SCHED, "C E %u %u %lu %u\r\n", 
        slotNum, 
        (call CXLinkPacket.getLinkHeader(msg))->destination,
        timestamp(msg) - baseCTS, 
        call CXLinkPacket.rxHopCount(msg));
      state = S_STATUS_WAIT_READY;
      cdbg(SCHED_CHECKED, "f FT.sp %lu - %lu = %lu,  %lu @ %lu\r\n",
        timestamp(msg), RX_SLACK, 
        timestamp(msg) - RX_SLACK,
        FRAME_LENGTH, 
        call FrameTimer.getNow());
      //synchronize receives to CTS timestamp - slack
      call FrameTimer.startOneShotAt(timestamp(msg) - RX_SLACK,
        FRAME_LENGTH * framesElapsed);
//      call FrameTimer.startPeriodicAt( timestamp(msg) - RX_SLACK, FRAME_LENGTH);
    }
  }

  event message_t* SubReceive.receive(message_t* msg, void* pl,
      uint8_t len){
    rxTime = timestamp(msg);
    call RoutingTable.addMeasurement(call CXLinkPacket.source(msg), 
      call ActiveMessageAddress.amAddress(), 
      call CXLinkPacket.rxHopCount(msg));
    cdbg(SCHED_CHECKED, "sr.r %x\r\n", call CXMacPacket.getMacType(msg));
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
          cerror(SCHED, "US1 %x\r\n", 
            state);
        }
        logReception(msg);
        return msg;

      case CXM_STATUS:
        {
          cx_status_t* status = (cx_status_t*) (call Packet.getPayload(msg, sizeof(cx_status_t)));
          if (! call SlotTimer.isRunning()){
            cdbg(SCHED, "CSBS\r\n");
            //if we receive a status message
            //  before we've received any CTS messages, slot timer is
            //  not set up yet. Our best guess is that it's one frame
            //  + RX_SLACK before the status message.
            call SlotTimer.startPeriodicAt(timestamp(msg)-FRAME_LENGTH-RX_SLACK, SLOT_LENGTH);

          }
          if (! call FrameTimer.isRunning()){
            cdbg(SCHED, "CSBF\r\n");
            //likewise, if we didn't start the frame timer (because we
            //missed the CTS), we kick it off now.
            call FrameTimer.startPeriodicAt(timestamp(msg), FRAME_LENGTH);
          }
          call RoutingTable.addMeasurement(
            call CXLinkPacket.destination(msg),
            call CXLinkPacket.source(msg), 
            status->distance);
  
          if (status->dataPending && shouldForward(call CXLinkPacket.source(msg), 
              call CXLinkPacket.destination(msg), status->bw)){
            slotRole = ROLE_FORWARDER;
            cdbg(SCHED, "S F %u %u %u %u\r\n", 
              slotNum, 
              call CXLinkPacket.source(msg),
              call CXLinkPacket.getSn(msg),
              call CXLinkPacket.rxHopCount(msg));
            state = S_ACTIVE_SLOT;
          } else {
            error_t error = call CXLink.sleep();
            slotRole = ROLE_NONFORWARDER;
            cdbg(SCHED, "S S %u %u %u %x %u\r\n", 
              slotNum, 
              call CXLinkPacket.source(msg), 
              call CXLinkPacket.getSn(msg),
              status->dataPending,
              call CXLinkPacket.rxHopCount(msg));
            call FrameTimer.stop();
            if (error != SUCCESS){
              cerror(SCHED, "sleep0 %x\r\n", error);
            }
            state = S_UNUSED_SLOT;
          }
          logReception(msg);
          return call SlotController.receiveStatus[activeNS](msg, status);
        }

      case CXM_EOS:
        cdbg(SCHED, "RE %u %u %u\r\n",
          slotNum,
          call CXLinkPacket.source(msg),
          call CXLinkPacket.getSn(msg));
        logReception(msg);
        return call SlotController.receiveEOS[activeNS](msg, 
          call Packet.getPayload(msg, sizeof(cx_eos_t)));

      case CXM_DATA:
        cdbg(SCHED, "RD %u %u %u %u %u\r\n",
          slotNum,
          call CXLinkPacket.source(msg),
          call CXLinkPacket.getSn(msg),
          call Packet.payloadLength(msg),
          call CXLinkPacket.rxHopCount(msg));
        logReception(msg);
        return signal Receive.receive(msg, 
          call Packet.getPayload(msg, call Packet.payloadLength(msg)), 
          call Packet.payloadLength(msg));

      default:
        cerror(SCHED, "UCXM %x\r\n", 
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
      pl -> bw = call SlotController.bw[activeNS](activeNS);
      pl -> distance = call RoutingTable.getDistance(master, 
        call ActiveMessageAddress.amAddress());
      pl -> wakeupRC = call RebootCounter.get();
      pl -> wakeupTS = wakeupStartMilli;
      //These fields are somewhat application specific. It would be
      //better if this component called a configureStatus interface
      //that could be specified on an application-by-application
      //basis (or ignored) and would fill in a second nested payload.

      #if CX_BASESTATION == 1
      pl -> role = ROLE_BASESTATION;
      #elif CX_ROUTER == 1
      pl -> role = ROLE_ROUTER;
      #else
      pl -> role = ROLE_LEAF;
      #endif

      pl -> pushCookie = call PushCookie.get();
      pl -> writeCookie = call WriteCookie.get();
      pl -> missingLength = call MissingLength.get();
      pl -> subnetChannel = (call ProbeSchedule.get())->channel[NS_SUBNETWORK];
      #ifndef DEFAULT_SAMPLE_INTERVAL
      #define DEFAULT_SAMPLE_INTERVAL 0
      #endif
      pl -> sampleInterval = DEFAULT_SAMPLE_INTERVAL;
      call SettingsStorage.get(SS_KEY_TOAST_SAMPLE_INTERVAL,
        &(pl->sampleInterval), sizeof(pl->sampleInterval));
      memset(&pl->barcode, 0xff, GLOBAL_ID_LEN);
      call SettingsStorage.get(TAG_GLOBAL_ID,
        &(pl->barcode), GLOBAL_ID_LEN);
      call Neighborhood.copyNeighborhood(pl->neighbors);
      //indicate whether there is any data to be sent.
      pl -> dataPending = (pendingMsg != NULL);
      cdbg(SCHED, "SR %x\r\n", pl->dataPending);
      state = S_STATUS_READY;
      //great. when we get the next FrameTimer.fired, we'll send it
      //out.
    }else{
      cerror(SCHED, "SMSG\r\n");
    }
  }

  event void FrameTimer.fired(){
    uint32_t targetAlarm;
    if (! call FrameTimer.isRunning()){
      targetAlarm = call FrameTimer.gett0() + call FrameTimer.getdt();
      call FrameTimer.startPeriodicAt(call FrameTimer.gett0(),
        FRAME_LENGTH);
    }else{
      targetAlarm = call FrameTimer.gett0();
    }
    framesLeft --;
    if (pendingRX || pendingTX){
      cdbg(SCHED_CHECKED, "FTP %x %x %x\r\n", pendingRX, pendingTX, state);
      //ok. we are still in the process of receiving/forwarding a
      //packet, it appears.
      //pass
    } else if (framesLeft <= EOS_FRAMES){
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
            //We compute EOS_FRAMES based on CTS_TIMEOUT, so it
            //  shouldn't be possible to have an RX here that spills
            //  over into next cts period.
            error_t error = rx(CTS_TIMEOUT, TRUE);
//            cdbg(SCHED, "NSW\r\n");
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
              cerror(SCHED, "EOS\r\n");
              state = S_ACTIVE_SLOT;
              return;
            }else{
              cx_eos_t* pl = call Packet.getPayload(eosMsg,
                sizeof(cx_eos_t));
              call Packet.clear(eosMsg);
              call CXMacPacket.setMacType(eosMsg, CXM_EOS);
              pl -> dataPending = (explicitDataPending || (pendingMsg != NULL));
              explicitDataPending = FALSE;
//              printf("dp %x\r\n", pl->dataPending);
              call CXLinkPacket.setDestination(eosMsg, master);
            }
          }
          //fall through
        case S_SLOT_END_READY:
          {
            error_t error = send(eosMsg, sizeof(cx_eos_t), 
              call SlotController.maxDepth[activeNS](activeNS),
              call FrameTimer.gett0()+TX_SLACK);
            if (error == SUCCESS){
              cdbg(SCHED_CHECKED, "SES\r\n");
              state = S_SLOT_END_SENDING;
            }else{ 
              cerror(SCHED, "ft.f %x %x fl 1\r\n", state, error);
            }
          }
          break;

        default:
          cerror(SCHED, "US2 %x fl 1\r\n", state);
          break;
      }
      call FrameTimer.stop();

    } else {
      lastTimer = call FrameTimer.gett0();
      lastFired = call FrameTimer.getNow();
      cdbg(SCHED_CHECKED, "FTN %x\r\n", state);
      switch (state){
        case S_STATUS_READY:
          {
            error_t error = send(statusMsg, sizeof(cx_status_t), 
              call SlotController.maxDepth[activeNS](activeNS),
              targetAlarm + TX_SLACK);
//            cwarn(SCHED, "SS %lu %lu\r\n", lastTimer, lastFired); 
            if (error == SUCCESS){
              state = S_STATUS_SENDING;
            }else{
              cerror(SCHED, "FT %x: SS.S %x\r\n", state, error);
            }
          }
          break;

        case S_STATUS_WAIT:
          framesWaited ++;
          if (framesWaited > call
          SlotController.maxDepth[activeNS](activeNS)){
            error_t error = call CXLink.sleep();
            if (error == SUCCESS){
              call FrameTimer.stop();
              state = S_UNUSED_SLOT;
            } else {
              cerror(SCHED, "STSF %x\r\n",
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
            #if ENABLE_FORWARDER_SELECTION == 0
            error_t error = send(pendingMsg, 
              pendingLen,
              call SlotController.maxDepth[activeNS](activeNS),
              call FrameTimer.gett0() + TX_SLACK);
            #else
            error_t error = send(pendingMsg, 
              pendingLen,
              call RoutingTable.getDistance(
                call ActiveMessageAddress.amAddress(), 
                call CXLinkPacket.destination(pendingMsg))
                + call SlotController.bw[activeNS](activeNS),
              call FrameTimer.gett0() + TX_SLACK);
            #endif
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
    #if ENABLE_FORWARDER_SELECTION == 0
    return call SlotController.maxDepth[activeNS](activeNS);
    #else
    return call RoutingTable.getDistance(
      call CXLinkPacket.source(msg),
      call CXLinkPacket.destination(msg)) 
      + call SlotController.bw[activeNS](activeNS);
    #endif
  }

  command error_t Send.send(message_t* msg, uint8_t len){
    if (pendingMsg != NULL){
      return EBUSY;
    } else {
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
            call SlotController.bw[activeNS](activeNS));
          //need to leave 1 frame for EOS message
          if (framesLeft <= clearTime(msg) + EOS_FRAMES){
//            printf("c\r\n");
            pendingMsg = NULL;
            cdbg(SCHED_CHECKED, "end\r\n");
            explicitDataPending = TRUE;
            state = S_SLOT_END_PREP;
            //Not enough space to send: so, clear it out and tell
            //upper layer to retry.
            return ERETRY;
          }else{
            cdbg(SCHED_CHECKED, "continue\r\n");
            state = S_DATA_READY;
          }
        }
        return SUCCESS;
      }else {
//        printf("h\r\n");
        //We don't yet have clearance to send, tell upper layer to
        //try again some time.
        return ERETRY;
      }
    }
  }

  error_t send(message_t* msg, uint8_t len, uint8_t ttl, 
      uint32_t txTime){
//    cdbg(SCHED, "S %u\r\n", ttl);
    if (pendingTX){
      return EBUSY;
    } else {
      error_t error;
      (call CXLinkPacket.getLinkMetadata(msg))->txTime = txTime;
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
    logTransmission(msg);
    cdbg(SCHED_RX, "LTX %u %lu %u %lu \r\n", 
      call CXLinkPacket.getSn(msg),
      timestamp(msg) - baseCTS,
      call Packet.payloadLength(msg),
      lastFired - baseCTS);
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
        cerror(SCHED, "USD %p got %p\r\n",
          statusMsg, msg);
      }
    }else if (state == S_DATA_SENDING){
      if (framesLeft <= clearTime(msg)){
        state = S_SLOT_END_PREP;
      }else{
        state = S_IDLE;
      }
      explicitDataPending = (call CXLinkPacket.getLinkMetadata(pendingMsg))->dataPending;
      pendingMsg = NULL;
      signal Send.sendDone(msg, error);
    } else if (state == S_CTS_SENDING){
      framesLeft = (SLOT_LENGTH/FRAME_LENGTH) - 1;
      if (! call SlotTimer.isRunning()){
        call SlotTimer.startPeriodicAt(timestamp(msg)-TX_SLACK, SLOT_LENGTH);
      }

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
      cerror(SCHED, "USDS %x\r\n", state);
    }
//    #if LOG_CTS_TIME == 1
//    cdbg(SCHED, "LTX %lu\r\n",
//      timestamp(msg) - baseCTS);
//    #endif
  }


  event void CXLink.rxDone(){
    pendingRX = FALSE;
    rxEnd = call FrameTimer.getNow();
    cdbg(SCHED_RX, "LRX %lu %lu %lu %lu %lu\r\n", 
      rxStart - baseCTS, 
      rxTime - baseCTS,
      rxEnd - baseCTS,
      lastTimer - baseCTS,
      lastFired - baseCTS);
    post nextRX();
  }

  error_t rx(uint32_t timeout, bool retx){
    rxTime = baseCTS;
    if (pendingRX){
      cerror(SCHED, "RXP\r\n");
      return EBUSY;
    } else {
      error_t error = call CXLink.rx(timeout, retx);
      rxStart = call FrameTimer.getNow();
      if (error == SUCCESS){
        pendingRX = TRUE;
      }
      return error;
    }
  }

  bool wakeupTimeoutStillGoing(uint32_t t){
    return (t - wakeupStart) 
      < wakeupLen();
  }
  
  #if LOG_NEIGHBORHOOD == 1
  task void logNeighborhood(){
    nx_am_addr_t* neighbors = call Neighborhood.getNeighborhood();
    uint8_t nn = call Neighborhood.numNeighbors();
    uint8_t i;
    cdbg(SCHED, "NS %u %lu\r\n",
      call RebootCounter.get(),
      wakeupStart);
    for (i = 0; i < nn; i++){
      cdbg(SCHED, "NE %u %lu %u\r\n",
        call RebootCounter.get(),
        wakeupStart,
        neighbors[i]);
    }
  }
  #endif


  task void nextRX(){
    wrxCount ++;
    cdbg(SCHED_CHECKED, "next RX ");
    if (state == S_WAKEUP){
      uint32_t t = call SlotTimer.getNow();
      bool stillWaking = wakeupTimeoutStillGoing(t);
      cdbg(SCHED_CHECKED, "wakeup\r\n");
      if (stillWaking){
        // - allow rest of network to wake up
        // - add 1 slow frame for the first CTS to go down
        uint32_t remainingTime = slowToFast(
          wakeupLen() - (t - wakeupStart) + FRAMELEN_SLOW);
        error_t error;
        cdbg(SCHED_CHECKED, "rx for %lu / %lu (%lu)\r\n", 
          remainingTime, wakeupLen(), 
          slowToFast(wakeupLen()));
        //Got an EBUSY here: this came from CXLinkP, where we were in
        //  state S_TX (perhaps sending a probe?)
        //Since we are no longer stillWaking, we start things up by
        //sending a CTS (which also fails because we're busy), and so
        //on.
        error = rx(remainingTime, TRUE);
        if (error != SUCCESS){
          cwarn(SCHED, "WURR %x\r\n", error);
          if (wrxCount < WRX_LIMIT){
            post nextRX();
            return;
          }else{
            endActive();
          }
//          stillWaking = FALSE;
        }
      } 
      if (! stillWaking){
        cdbg(SCHED_CHECKED, "Done waking\r\n");
        if (call SlotController.isMaster[activeNS]()){
          call SlotTimer.startOneShot(0);
//          signal SlotTimer.fired();
        } else {
          probe_schedule_t* sched = call ProbeSchedule.get();
//          error_t error = rx(slowToFast(2*sched->probeInterval*sched->invFrequency[activeNS]), 
//            TRUE);
          error_t error = rx(slowToFast(2*sched->probeInterval), 
            TRUE);
          if (error != SUCCESS){
            cerror(SCHED, "SRXF %x\r\n", error);
            error = endActive();
            if (error != SUCCESS){
              //awjeez awjeez
              cerror(SCHED, "FS 1 %x\r\n", error);
            }
          }else{
            state = S_SLOT_CHECK;
          }
        }
      }
    }else if (state == S_SLOT_CHECK){
      missedCTS++;
      slotRole = ROLE_NO_CTS;
      if (missedCTS < MISSED_CTS_THRESH && call SlotTimer.isRunning()){
        cdbg(SCHED, "MCC %u %u\r\n", slotNum, missedCTS);

        #if LOG_CTS_TIME == 1
        cdbg(SCHED, "MC %lu\r\n", ctsStart-baseCTS);
        #endif
        call FrameTimer.stop();
        call CXLink.sleep();
        state = S_UNUSED_SLOT;
      }else {
        //CTS limit exceeded, back to sleep
        error_t error = endActive();
        cdbg(SCHED, "MCD %u %u %u\r\n", slotNum, missedCTS, call SlotTimer.isRunning());
        if(error != SUCCESS){
          //awjeez awjeez
          cerror(SCHED, "FS 0 %x\r\n", error);
        }
      }
    }else{
      //ignore next rx (e.g. handled at frametimer.fired)
      cdbg(SCHED_CHECKED, "nrxi %x\r\n", state);
    }
  }

  error_t endActive() {
    error_t error = call LppControl.sleep();
    call SlotTimer.stop();
    call FrameTimer.stop();
    logStats();
    #if LOG_NEIGHBORHOOD == 1
    call Neighborhood.freeze();
    post logNeighborhood();
    #endif
    state = S_UNSYNCHED;
    cinfo(SCHED, "SLEEP %u\r\n", 
      (call ProbeSchedule.get())->channel[activeNS]);
    signal DownloadNotify.downloadFinished[activeNS]();
    return error;
  }
  
  #if DL_STATS <= DL_INFO && DL_GLOBAL <= DL_INFO
  void logStats(){
    call StatsLog.logSlotStats(call CXLink.getStats(), 
      wakeupNum, slotNum, slotRole);
    //slot stats
    ctsReceived = FALSE;
    slotRole = ROLE_UNKNOWN;
  }

  void logReception(message_t* msg){
    call StatsLog.logReception(msg, wakeupNum, slotNum);
  }

  void logTransmission(message_t* msg){
    call StatsLog.logTransmission(msg, wakeupNum, slotNum);
  }
  #else
  void logStats(){}
  void logTransmission(message_t* msg){}
  void logReception(message_t* msg){}
  #endif
  
  //when slot timer fires, master will send CTS, and slave will try to
  //check for it.
  event void SlotTimer.fired(){
    framesLeft = SLOT_LENGTH/FRAME_LENGTH;
    logStats();
    slotNum ++;
    if (signalEnd){
      call SlotController.endSlot[activeNS]();
      signalEnd = FALSE;
    }else{
      if (call SlotController.isMaster[activeNS]()){
        //ugh, correct slot numbering at master
        slotNum --;
      }
    }

    //NB we could still be in S_SLOT_END if we miss a status
    //message, wait for the end-of-slot message, and the time for an
    //EOS RX to finish spills over the last frame. This shouldn't
    //happen if EOS_FRAMES is defined correctly (the number of frames
    //required for a max-depth short-packet flood)
    if (call SlotController.isMaster[activeNS]()){
      if(call SlotController.isActive[activeNS]()){
        am_addr_t activeNode = 
          call SlotController.activeNode[activeNS]();
        cdbg(SCHED_CHECKED, "SS %u A %u\r\n", slotNum, activeNode);
        cdbg(SCHED_CHECKED, "master + active: next %x\r\n", activeNode);
        signalEnd = TRUE;
        if (ctsMsg == NULL){
          ctsMsg = call Pool.get();
          if (ctsMsg == NULL){
            cerror(SCHED, "CTSPE\r\n");
          } else {
            error_t error;
            cx_lpp_cts_t* pl = call Packet.getPayload(ctsMsg,
              sizeof(cx_lpp_cts_t));
            call Packet.clear(ctsMsg);
            call CXMacPacket.setMacType(ctsMsg, CXM_CTS);
            pl -> slotNum = slotNum;
            call CXLinkPacket.setDestination(ctsMsg, activeNode);
            //header only
            #if LOG_CTS_TIME == 1
            ctsStart = call FrameTimer.getNow();
            #endif
            error = send(ctsMsg, 0,
              call SlotController.maxDepth[activeNS](activeNS),
              call SlotTimer.gett0() + TX_SLACK);
//            cinfo(SCHED, "ST.F %lu %lu %lu\r\n", 
//              call SlotTimer.getNow(),
//              call SlotTimer.gett0(),
//              call SlotTimer.getdt());
            if (error == SUCCESS){
              state = S_CTS_SENDING;
            }else{
              cerror(SCHED, "CTSSF %x\r\n", error);
              call Pool.put(ctsMsg);
              ctsMsg = NULL;
            }
          }
        } else {
          cerror(SCHED, "CTSB\r\n");
        }
      } else {
        error_t error = endActive();
        cdbg(SCHED, "EA %x\r\n", error);
      }
    } else {
      error_t error;
      #if LOG_CTS_TIME == 1
      ctsStart = call FrameTimer.getNow();
      #endif
      error = rx(CTS_TIMEOUT, TRUE);
      state = S_SLOT_CHECK;
      if (error != SUCCESS){
        cerror(SCHED, "CTSLF %x\r\n", error);
        missedCTS++;
        post nextRX();
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
  default command uint8_t SlotController.bw[uint8_t ns](uint8_t ns1){
    return 0;
  }
  default command uint8_t SlotController.maxDepth[uint8_t ns](uint8_t ns1){
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
  default command void SlotController.receiveCTS[uint8_t ns](am_addr_t m, uint8_t ans){}
  default command void SlotController.endSlot[uint8_t ns](){}

  event void StateDump.dumpRequested(){}

  default event void DownloadNotify.downloadStarted[uint8_t ns](){}
  default event void DownloadNotify.downloadFinished[uint8_t ns](){}

  default command uint32_t PushCookie.get(){
    return 0;
  }

  default command uint32_t WriteCookie.get(){
    return 0;
  }
  default command uint32_t MissingLength.get(){
    return 0;
  }

  default command void StatsLog.logSlotStats(cx_link_stats_t stats_, 
    uint16_t wakeupNum_, int16_t slotNum_, uint8_t slotRole_){}
  default command void StatsLog.logReception(message_t* msg_, 
    uint16_t wakeupNum_, int16_t slotNum_){}
  default command void StatsLog.logTransmission(message_t* msg_, 
    uint16_t wakeupNum_, int16_t slotNum_){}
  default command void StatsLog.flush(){}
}
