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


 #include "Rf1a.h"
 #include "CXFlood.h"
 #include "SchedulerDebug.h"
 #include "SFDebug.h"
module CXScopedFloodP{
  provides interface Send[uint8_t t];
  provides interface Receive[uint8_t t];

  uses interface CXPacket;
  uses interface CXPacketMetadata;
  uses interface AMPacket;
  //Payload: body of CXPacket (a.k.a. header of AM packet, if it's AM
  //data)
  uses interface Packet as LayerPacket;
  uses interface CXTDMA;
  uses interface TDMARoutingSchedule;
  uses interface CXTransportSchedule[uint8_t tProto];
  uses interface TaskResource;

  uses interface CXRoutingTable;
} implementation {

  #define ACKS_PER_DATA 2
  enum{
    S_IDLE = 0x00,

    S_DATA = 0x01,
    S_ACK_WAIT = 0x02,
    S_ACK = 0x03,
    S_ACK_PREPARE = 0x04,

    S_CLEAR_WAIT = 0x05,
    S_CLEAR_WAIT_SETUP = 0x06,

    S_ERROR = 0x10,

  };
  uint8_t state = S_IDLE;

  //TODO: might be easier to make this isAckOrigin and isDataOrigin
  //      or: clear it when switching to ACK if you're not the origin
  //for determining whether to use origin_xxx or fwd_msg
  bool isOrigin;

  //indicates that Send has requested data transmission at the next
  //available time.
  bool originDataPending;
  //indicates that we have sent the data requested by the Send
  //interface (so that we know to signal SendDone at some point).
  bool originDataSent;
  
  //acks which we generate in this layer
  message_t origin_ack_internal;
  message_t* origin_ack_msg = &origin_ack_internal;
  uint8_t origin_ack_len = sizeof(cx_header_t) + sizeof(cx_ack_t) +
    sizeof(rf1a_nalp_am_t);

  //local buffer for swapping with packets received from lower layer
  message_t rx_msg_internal;
  message_t* rx_msg = &rx_msg_internal;
  uint8_t rx_len;
  
  //provided by Send interface. 
  message_t* origin_data_msg;
  error_t sendDoneError;
  
  //shared by forwarded data and forwarded acks.
  message_t fwd_msg_internal;
  message_t* fwd_msg = &fwd_msg_internal;
  uint8_t fwd_len;
  
  //for determining when to transition states
  uint8_t TXLeft;
  uint8_t waitLeft;

  //race condition guard variables
  bool routeUpdatePending;
  bool rxOutstanding;
  bool clearTimePending;
  
  //for matching up acks with data and suppressing duplicate data
  //receptions
  uint16_t lastDataSrc;
  uint32_t lastDataSn;
  
  //route update variables
  uint8_t ruSrcDepth;
  uint8_t ruAckDepth;
  uint8_t ruDistance;
  uint16_t ruSrc;
  uint16_t ruDest;
  bool routeUpdatePending;

  uint16_t originFrame;
  uint16_t clearFrame;
  
  //for debug
  uint16_t ssdFrame;
  uint16_t ecwFrame;
  uint16_t ackFrame;
  uint16_t dataReceivedFrame;
  uint8_t ssdPoster;

  //forward declarations
  void signalSendDone();
  task void routeUpdate();
  task void clearTimeUpdate();
  
  void setState(uint8_t s){
    printf_SF_STATE("{%x->%x}\r\n", state, s);
    state = s;
  }

  /**
   * Distinguish data and ack frames from each other (so that
   * getPacket knows what to provide)
   */
  bool isDataFrame(uint16_t frameNum){
    uint16_t localF = frameNum % (call TDMARoutingSchedule.framesPerSlot());
    return ((localF%(ACKS_PER_DATA + 1)) == 0);
  }
  bool isAckFrame(uint16_t frameNum){
    return ! isDataFrame(frameNum);
  }
  
  message_t* dispMsg;
  task void displayPacket(){
    uint8_t i;
    ieee154_header_t* header154 
      = ((ieee154_header_t*)dispMsg->header);
    rf1a_metadata_t* md 
      = ((rf1a_metadata_t*) dispMsg->metadata);
    printf("msg: %p len %u\r\n", 
      dispMsg,
      md->payload_length);

    printf(" Raw 15.4 ");
    for (i = 0; i< sizeof(ieee154_header_t); i++){
      printf("%2X ", dispMsg->header[i]); 
    }
    printf("\r\n");
    #if MINIMAL_PACKET == 1
    printf(" 15.4 fcf: %x dsn: %x d: %x s: %x\r\n",
      header154->fcf,
      header154->dsn,
      header154->dest,
      header154->src);
    #else
    printf(" 15.4 fcf: %x dsn: %x dp: %x d: %x s: %x\r\n",
      header154->fcf,
      header154->dsn,
      header154->destpan,
      header154->dest,
      header154->src);
    #endif

    printf(" Raw CX   ");
    for (i=0; i< sizeof(cx_header_t); i++){
      printf("%2X ", dispMsg->data[i]);
    }
    printf("\r\n");
    printf(" CX d: %x sn: %x count: %x sched: %x of: %x ts: %lx np: %x tp: %x ntype: %x ttype: %x\r\n", 
      call CXPacket.destination(dispMsg),
      call CXPacket.sn(dispMsg),
      call CXPacket.count(dispMsg),
      call CXPacket.getScheduleNum(dispMsg),
      call CXPacket.getOriginalFrameNum(dispMsg),
      call CXPacket.getTimestamp(dispMsg),
      call CXPacket.getNetworkProtocol(dispMsg),
      call CXPacket.getTransportProtocol(dispMsg),
      call CXPacket.getNetworkType(dispMsg),
      call CXPacket.getTransportType(dispMsg));

    if (call CXPacket.getNetworkType(dispMsg) == CX_TYPE_DATA){
      printf("  Raw AM   ");
      for (i=0; i < sizeof(rf1a_nalp_am_t); i++){
        printf("%2X ",
          dispMsg->data[i+sizeof(cx_header_t)]);
      }
      printf("\r\n");
      printf(" AM d: %x s: %x t: %x\r\n", 
        call AMPacket.destination(dispMsg),
        call AMPacket.source(dispMsg),
        call AMPacket.type(dispMsg));
    }else{
      cx_ack_t* ack = call LayerPacket.getPayload(dispMsg,
        sizeof(cx_ack_t));
      printf(" ACK s: %x sn: %u d: %u\r\n", 
        ack->src,
        ack->sn,
        ack->depth);
    }
//    printf_TMP("pl (%u) ", 
//      (md->payload_length - sizeof(message_header_t)));
//    for (i=0; i < (md->payload_length - sizeof(message_header_t)); i++){
//      printf_TMP("%2X ", dispMsg->data[i]);
//    }
//    printf_TMP("\r\n");
  }

  uint8_t clearTime(uint8_t distance, bool isPrerouted){
    int8_t ackEdge; 
    int8_t dataEdge;
    uint8_t time=0;
    dataEdge = 0;
    printf_SF_CLEARTIME("#SF CT: d %u ", distance);
    //buffer zone width should be added to distance in either
    //  direction, but only if it's pre-routed
    if (isPrerouted){
      distance += 2*(call CXRoutingTable.getBufferWidth());
      printf_SF_CLEARTIME("pr -> %u ", distance);
    }
    ackEdge = -1*distance;
    while (dataEdge < distance){
      if (time % (ACKS_PER_DATA+1) == 0){
        dataEdge++;
      }
      time++;
    }
    while (ackEdge != dataEdge){
      if (time %(ACKS_PER_DATA+1) == 0){
        dataEdge++;
      }else{
        ackEdge++;
      }
      time++;
    }
    printf_SF_CLEARTIME("%u -> ", time);
    //conservatively, this should be 2*maxRetransmit*time
    //  because in worst-case, it takes maxRetransmit*data_time +
    //  maxRetransmit*ack_time. yeeesh
    //for reference, in a 5-hop network, worst case completion time
    //  with a single extra retx is 78 frames. 
    if (call TDMARoutingSchedule.maxRetransmit()){
      time = time*2*(call TDMARoutingSchedule.maxRetransmit()-1);
    }
    printf_SF_CLEARTIME("%u\r\n", time);
    return time;
  }

//  uint16_t tempCt;
//  uint16_t tempLeft;
////  am_addr_t tempDest;
//  task void printCt(){
//    printf_TMP("ct %u l %u\r\n", tempCt, tempLeft);
//  }

  //Buffer a packet from the transport layer if we're not already
  //holding one.
  command error_t Send.send[uint8_t t](message_t* msg, uint8_t len){
//    printf_TESTBED("ScopedFloodSend\r\n");
    if (!originDataPending){
      //compute clear time and compare to frames left in slot
      //if there's not enough time, return ERETRY
     uint8_t distance = call CXRoutingTable.advertiseDistance(TOS_NODE_ID,
        call CXPacket.destination(msg), TRUE);
      uint8_t ct;
      if (distance > call TDMARoutingSchedule.maxDepth()){
        distance = call TDMARoutingSchedule.maxDepth();
      }
      ct = clearTime(distance, 
        call CXPacket.getNetworkProtocol(msg) & CX_NP_PREROUTED)+1;
      if (ct > 
          call TDMARoutingSchedule.framesLeftInSlot(call
          TDMARoutingSchedule.currentFrame())){
        printf_SF_CLEARTIME("#SF CT RETRY\r\n");
        return ERETRY;
      } else{
        printf_SF_CLEARTIME("#SF CT OK\r\n");
        origin_data_msg = msg;
        call CXPacket.init(msg);
        call CXPacket.setNetworkType(msg, CX_TYPE_DATA);
        //preserve pre-routed bit
        call CXPacket.setNetworkProtocol(msg, 
          ((call CXPacket.getNetworkProtocol(msg)) & CX_NP_PREROUTED)
          | CX_NP_SCOPEDFLOOD);
        originDataPending = TRUE;
        return SUCCESS;
      }
    } else {
      return EBUSY;
    }
  }
  
  command error_t Send.cancel[uint8_t t](message_t* msg){
    //TODO: this should: 
    // - free the resource. 
    // - reset originDataPending to FALSE
    // - put us back into S_IDLE
    //if msg is NULL, this should
    //also signal sendDone to indicate what happened (so that we can
    //invoke this from a lower layer than the application sees).
    return FAIL;
  }



  event rf1a_offmode_t CXTDMA.frameType(uint16_t frameNum){ 
    //Check for (implicit) completion of SF: clearFrame is set in
    //CXTDMA.sendDone at the point where we enter the S_CLEAR_WAIT
    //state
    if ((state == S_CLEAR_WAIT)){
      if ( frameNum >= clearFrame){
        ssdFrame = frameNum;
        ssdPoster = 0;
        signalSendDone();
        return RF1A_OM_RX;
//      }else{
//        printf_TMP("%u!=%u\r\n", frameNum, clearFrame);
      }
    }

    //check for end of ACK_WAIT and clean up 
    if (state == S_ACK_WAIT){
      //TODO: this should also use something analogous to clearFrame rather than a countdown
      waitLeft --;
      printf_SF_TESTBED_AW("WL %u %u %u\r\n", frameNum, 
        call TDMARoutingSchedule.framesPerSlot(), 
        waitLeft);
      if (waitLeft == 0){
        isOrigin = FALSE;
        routeUpdatePending = FALSE;
        lastDataSrc = 0xffff;
        lastDataSn = 0;
        //no ack by the end of the slot, done.
        if (originDataSent){
          sendDoneError = ENOACK;
          ssdFrame = frameNum;
          ssdPoster = 1;
          signalSendDone();
        }else{
          call TaskResource.release();
          //get ready for next slot
          setState(S_IDLE);
        }
      }
    }

    if (originDataPending 
        && isDataFrame(frameNum) 
        && call CXTransportSchedule.isOrigin[call CXPacket.getTransportProtocol(origin_data_msg)](frameNum)){
      if (state == S_IDLE){
        //TODO: should move request/release of this resource into
        //functions that perform any necessary book-keeping.
        if (SUCCESS == call TaskResource.immediateRequest()){
          uint8_t mr = call TDMARoutingSchedule.maxRetransmit();
          uint16_t dataFramesLeft = 
            call TDMARoutingSchedule.framesLeftInSlot(frameNum) /
            (ACKS_PER_DATA + 1);
          TXLeft = (mr < dataFramesLeft)? mr : dataFramesLeft;
          lastDataSrc = TOS_NODE_ID;
          lastDataSn = call CXPacket.sn(origin_data_msg);
          setState(S_DATA);
          isOrigin = TRUE;
          originFrame = frameNum;
//          printf_TMP("#O@ %u\r\n", frameNum);
          return RF1A_OM_FSTXON;
        } else {
          printf("!SF.ft.RIR\r\n");
          return RF1A_OM_RX;
        }
      }else{
        //busy already, so leave it. This shouldn't happen if all the
        //nodes are scheduled properly.
      }
    }

    switch (state){
      case S_DATA:
        if (isDataFrame(frameNum)){
          if ( call TaskResource.isOwner()){
//            printf_TMP("#D@ %u\r\n", frameNum);
            return RF1A_OM_FSTXON;
          } else {
            printf("!in s_data, but resource not held.\r\n");
            return RF1A_OM_UNDEFINED; 
          }
        } else {
          return RF1A_OM_RX;
        }
      case S_ACK:
        if (isAckFrame(frameNum)){
          if (call TaskResource.isOwner()){
//            printf_TMP("#A@ %u\r\n", frameNum);
            return RF1A_OM_FSTXON;
          }else{
            printf("!in s_ack, but resource not held.\r\n");
            return RF1A_OM_UNDEFINED;
          }
        } else {
          return RF1A_OM_RX;
        }
      case S_CLEAR_WAIT:
        //TODO: can we actually be idle during this time? Should be
        //OK.
        return RF1A_OM_RX;
      case S_IDLE:
        return RF1A_OM_RX;
      case S_ACK_WAIT:
        return RF1A_OM_RX;
      default:
        return RF1A_OM_RX;
    }
    return RF1A_OM_RX;
  }

  uint16_t rgpFN;
  message_t* rgpMsg;
  task void reportGetPacket(){
    printf_TMP("CXSF.gp: %p @%u\r\n", rgpMsg, rgpFN);
  }

  event bool CXTDMA.getPacket(message_t** msg,
      uint16_t frameNum){ 
    printf_SF_GP("gp");
    if (isDataFrame(frameNum)){
      printf_SF_GP("d");
      if (isOrigin ){
        SF_GPO_SET_PIN;
        printf_SF_GP("o");
        originDataSent = TRUE;
        *msg = origin_data_msg;
        SF_GPO_CLEAR_PIN;
        rgpFN = frameNum;
        rgpMsg = *msg;
//        post reportGetPacket();
      } else{
        SF_GPF_SET_PIN;
        printf_SF_GP("f");
        *msg = fwd_msg;
        SF_GPF_CLEAR_PIN;
      }
      printf_SF_GP("\r\n");
      return TRUE;
    } else if (isAckFrame(frameNum)){
      printf_SF_GP("a");
      if (isOrigin){
        SF_GPO_SET_PIN;
        printf_SF_GP("o");
        *msg = origin_ack_msg;
        SF_GPO_CLEAR_PIN;
        rgpFN = frameNum;
        rgpMsg = *msg;
//        post reportGetPacket();
      } else {
        SF_GPF_SET_PIN;
        printf_SF_GP("f");
        *msg = fwd_msg;
        SF_GPF_CLEAR_PIN;
      }
      printf_SF_GP("\r\n");
      return TRUE;
    }
    printf("SF.GP!\r\n");
    return FALSE;
  }

  void signalSendDone(){
    originDataPending = FALSE;
    originDataSent = FALSE;
    ecwFrame = 0;
    call TaskResource.release();
    setState(S_IDLE);
    signal Send.sendDone[call CXPacket.getTransportProtocol(origin_data_msg)](origin_data_msg, sendDoneError);
//    printf_TMP("ssd.%u@%u(%u,%u)\r\n", ssdPoster, ssdFrame, ackFrame, ecwFrame);
  }

//  task void printAckTiming(){
//    printf_TMP("d@%ua@%u\r\n", dataReceivedFrame, ackFrame);
//  }

  event error_t CXTDMA.sendDone(message_t* msg, uint8_t len,
      uint16_t frameNum, error_t error){
//    printf_TMP("cx.sd\r\n");
////    dispMsg = msg;
////    post displayPacket();
    if(TXLeft != 0){
      TXLeft --;
    }
    if (TXLeft == 0){
      if (state == S_DATA){
        //TODO: we should handle this like we do the CLEAR_WAIT below:
        //  if we are in this state, then we're either pre-routed and
        //  know the distance from src to dest (+original frame), or
        //  we're not prerouted and we know src + original frame.
        
        waitLeft = call TDMARoutingSchedule.framesLeftInSlot(frameNum)-1;
        setState(S_ACK_WAIT);
      }else if (state == S_ACK){
        post routeUpdate();
        if (originDataSent){
          //if the data we sent was pre-routed, we're done right
          //now. Might be good to wait for another frame for anything
          //left to clear.
          if ( call CXPacket.getNetworkProtocol(origin_data_msg) & CX_NP_PREROUTED){
            ssdFrame = frameNum;
            ssdPoster = 2;
            signalSendDone();
          } else { 
            ecwFrame = frameNum;
            clearTimePending = TRUE;
            setState(S_CLEAR_WAIT_SETUP);
          }
        } else {
          ackFrame = frameNum;
//          post printAckTiming();
          call TaskResource.release();
          setState(S_IDLE);
        }
      }else{
        printf("!Unexpected state %x at sf.cxtdma.sendDone\r\n", state);
      }
    }
    return SUCCESS;
  }


  task void routeUpdate(){
    if (routeUpdatePending){
      //up to the routing table to do what it wants with it.
      // for AODV, all we really care about is whether we are
      // between the two: 
      //  src->me + me->dest  <= src->dest
      call CXRoutingTable.update(ruSrc, ruDest,
        ruDistance, TRUE);
      call CXRoutingTable.update(ruSrc, TOS_NODE_ID, 
        ruSrcDepth, TRUE);
      call CXRoutingTable.update(ruDest, TOS_NODE_ID,
        ruAckDepth, TRUE);
      routeUpdatePending = FALSE;
    }
    if (clearTimePending){
      post clearTimeUpdate();
    }
  }

  task void clearTimeUpdate(){
    if (state == S_CLEAR_WAIT_SETUP){
//      uint8_t dist = call CXRoutingTable.distance(TOS_NODE_ID,
//        call CXPacket.destination(origin_data_msg)); 
//      printf_TMP("cf %x(%u) = ", 
//        call CXPacket.destination(origin_data_msg), 
//        dist);
      //subtract 1: clearTime+originFrame is the first frame for which
      //  the air is clear. So, we should signal completion after the
      //  transmission in frame ct+origin - 1
      clearFrame = clearTime(
        call CXRoutingTable.advertiseDistance(TOS_NODE_ID, 
          call CXPacket.destination(origin_data_msg), TRUE), 
        call CXPacket.getNetworkProtocol(origin_data_msg)&CX_NP_PREROUTED) 
        + originFrame - 1;
//      printf_TMP("c@%u\r\n", clearFrame);
      //For the case where it's already done
      if (clearFrame >= ecwFrame){
        signalSendDone();
      } else{
        setState(S_CLEAR_WAIT);
      }
      clearTimePending = FALSE;
    }
  }

  //generate an ack, get a new RX buffer, and ready for sending acks.
  task void processReceive(){
    if (state == S_ACK_PREPARE){
      cx_ack_t* ack = (cx_ack_t*)(call LayerPacket.getPayload(origin_ack_msg, sizeof(cx_ack_t)));
      uint8_t tp = call CXPacket.getTransportProtocol(rx_msg);
      uint8_t pll = call LayerPacket.payloadLength(rx_msg);
      void* pl = call LayerPacket.getPayload(rx_msg, pll);
    
      call LayerPacket.setPayloadLength(origin_ack_msg,
        sizeof(cx_ack_t));

      call CXPacket.init(origin_ack_msg);
      call CXPacket.setSource(origin_ack_msg, TOS_NODE_ID);
      call CXPacket.setNetworkType(origin_ack_msg, CX_TYPE_ACK);
      call CXPacket.setNetworkProtocol(origin_ack_msg, CX_NP_SCOPEDFLOOD);
      call CXPacket.setDestination(origin_ack_msg, call CXPacket.source(rx_msg));
      call CXPacket.setTransportProtocol(origin_ack_msg, 
        call CXPacket.getTransportProtocol(rx_msg));
      call CXPacket.setSource(origin_ack_msg, TOS_NODE_ID);
      ack -> src = call CXPacket.source(rx_msg);
      ack -> sn  = call CXPacket.sn(rx_msg);
      ack -> depth = call CXPacket.count(rx_msg);
      isOrigin = TRUE;

      //route update goodness
      ruSrcDepth = call CXPacket.count(rx_msg);
      ruSrc = call CXPacket.source(rx_msg);
      ruDest = call CXPacket.source(origin_ack_msg);
      ruAckDepth = 0;
      ruDistance = ruSrcDepth;
      routeUpdatePending = TRUE;
      rx_msg = signal Receive.receive[tp](rx_msg, pl, pll);
      setState(S_ACK);
    }
  }

  /**
   * Receive packet and decide whether to drop it or forward it. For
   * acknowledgments to packets which we sent, update return code to
   * indicate ack was received.
   */
  event message_t* CXTDMA.receive(message_t* msg, uint8_t len,
      uint16_t frameNum, uint32_t timestamp){
    uint8_t pType = call CXPacket.getNetworkType(msg);
    uint32_t sn = call CXPacket.sn(msg);
    am_addr_t src = call CXPacket.source(msg);
    am_addr_t dest = call CXPacket.destination(msg);
    printf_SF_RX("#rx %p %x ", msg, state);

    //TODO: better duplicate-handling as in flood
    if (!call TDMARoutingSchedule.isSynched()){
      printf_SF_RX("NS\r\n");
      //non-synched, drop it.
      return msg;
    }
    if (state == S_IDLE){
      if ( ! call TDMARoutingSchedule.isSynched()){
        printf_SF_RX("~s");
        return msg;
      }else{
        printf_SF_RX("s");
      }

      printf_SF_RX("i");
      //drop pre-routed packets for which we aren't on a route.
      if (call CXPacket.getNetworkProtocol(msg) & CX_NP_PREROUTED){
        bool isBetween;
        printf_SF_RX("p");
        if ((SUCCESS != call CXRoutingTable.isBetween(src, 
            call CXPacket.destination(msg), TRUE, &isBetween)) || !isBetween){
          uint8_t tp = call CXPacket.getTransportProtocol(msg);
          uint8_t pll = call LayerPacket.payloadLength(msg);
          void* pl = call LayerPacket.getPayload(msg, pll);
          printf_SF_TESTBED_PR("PRD %u %lu\r\n", src, sn);
          printf_SF_RX("x*\r\n");
          //no need to forward it, but report up for snooping.
          return signal Receive.receive[tp](msg, pl, pll);
        }else{
          printf_SF_TESTBED_PR("PRK %u %lu\r\n", src, sn);
        }
      }
      //OK: the state guards us from overwriting rx_msg. the only time
      //that we write to it is when we are in idle.
      //New data
      if (pType == CX_TYPE_DATA){
        message_t* ret;

        printf_SF_RX("d");
        //coming from idle: we are always going to need the resource.
        if ( SUCCESS != call TaskResource.immediateRequest()){
          printf("!SF.r.RIR\r\n");
          return msg;
        }

        //record src/sn so we can match it to ack
        lastDataSrc = src;
        lastDataSn = sn;
        
        //record our distance from the data source.
        ruSrcDepth = call CXPacket.count(msg);

        //for me: save it for RX and prepare to send ack.
        if (dest == TOS_NODE_ID){
          uint8_t mr = call TDMARoutingSchedule.maxRetransmit();
          uint16_t fl =
             call TDMARoutingSchedule.framesLeftInSlot(frameNum);
          uint16_t ackFramesLeft =
            ( fl/ (ACKS_PER_DATA + 1)) * ACKS_PER_DATA;
//          printf_TMP("fn: %u mr: %u fl: %u afl: %u\r\n", frameNum, 
//            mr, fl, ackFramesLeft);
          TXLeft = (mr < ackFramesLeft)?mr:ackFramesLeft;
          printf_SF_RX("M");
          ret = rx_msg;
          rx_msg = msg;
          rx_len = len;
          dataReceivedFrame = frameNum;
          post processReceive();
          setState(S_ACK_PREPARE);
        //not for me: forward it.
        }else {
          uint8_t mr = call TDMARoutingSchedule.maxRetransmit();
          uint16_t dataFramesLeft = 
            call TDMARoutingSchedule.framesLeftInSlot(frameNum) /
            (ACKS_PER_DATA + 1);
          printf_SF_ROUTE("D %u %u %u\r\n", src, dest, frameNum);
          printf_SF_RX("f");
          ret = fwd_msg;
          fwd_msg = msg;
          fwd_len = len;
          //data packet: if there are n framesLeft, dataFramesLeft is
          //n/3.
          TXLeft = (mr < dataFramesLeft)? mr : dataFramesLeft;
          isOrigin = FALSE;
          setState(S_DATA);
          //TODO: should be able to snoop data.
        }
        printf_SF_RX("\r\n");
        return ret;

      //ignore acks for which we have seen no data: this happens at
      //the edge of the flood.
      } else if (pType == CX_TYPE_ACK){
        printf_SF_RX("a*\r\n");
        return msg;
           
      } else {
        printf("SF Unhandled CX type!\r\n");
        return msg;
      }
    } else if ((state == S_DATA) || (state == S_ACK_WAIT)){
      printf_SF_RX("d");
      //ignore data receptions
      if (pType == CX_TYPE_DATA){
        printf_SF_RX("d*\r\n");
        return msg;

      //ack: verify that it matches the data, handle according to
      //whether it's destined for us or not, start forwarding it.
      } else if (pType == CX_TYPE_ACK){
        cx_ack_t* ack = (cx_ack_t*) (call LayerPacket.getPayload(msg,
          sizeof(cx_ack_t)));
        printf_SF_ROUTE("A %u %u %u\r\n", src, dest, frameNum);
        printf_SF_RX("a");
        if ( (ack->src == lastDataSrc) && (ack->sn == lastDataSn) ){
          message_t* ret = fwd_msg;
          uint8_t mr = call TDMARoutingSchedule.maxRetransmit();
          uint16_t ackFramesLeft = 
            (call TDMARoutingSchedule.framesLeftInSlot(frameNum) /
            (ACKS_PER_DATA + 1)) * ACKS_PER_DATA;
          printf_SF_RX("m");
          fwd_msg = msg;
          fwd_len = len;
          TXLeft = (mr < ackFramesLeft)?mr:ackFramesLeft;
          
          //record routing information (our distance from the ack
          //  origin, src->dest distance)
          ruSrc = ack->src;
          ruDest = src;
          ruAckDepth = call CXPacket.count(msg);
//          printf_BF("rx ack: %x %u %u\r\n", ack->src, ack->sn, ack->depth);
          ruDistance = ack->depth;
          routeUpdatePending = TRUE;

          //we got an ack to data we sent. hooray!
          if (dest == TOS_NODE_ID){
            ackFrame = frameNum;
            printf_SF_RX("M");
            sendDoneError = SUCCESS;
            //This should be taken care of when we finish forwarding
            //these acks. Better to signal it at that point anyway.
//            post routeUpdate();
//            post signalSendDone();
          }
          isOrigin = FALSE;
          setState(S_ACK);
          printf_SF_RX("\r\n");
          return ret;
        }else{
          printf_SF_RX("o*\r\n");
          return msg;
        }

      } else {
        printf("SF Unhandled CX type!\r\n");
        return msg;
      }
      
    } else if (state == S_ACK){
      printf_SF_RX("a*\r\n");
      //already in the ack stage, so we will just keep on ignoring
      //these.
      return msg;
    } else if (state == S_CLEAR_WAIT){
      //ignore this if we're waiting for the air to clear.
      return msg;
    } else {
      printf("SF unhandled state %x!\r\n", state);
      return msg;
    }

  }

  command void* Send.getPayload[uint8_t t](message_t* msg, uint8_t len){ return call LayerPacket.getPayload(msg, len); }
  command uint8_t Send.maxPayloadLength[uint8_t t](){ return call LayerPacket.maxPayloadLength(); }
  default event void Send.sendDone[uint8_t t](message_t* msg, error_t error){}
  default event message_t* Receive.receive[uint8_t t](message_t* msg, void* payload, uint8_t len){ return msg;}

  default command bool CXTransportSchedule.isOrigin[uint8_t
  tProto](uint16_t frameNum){ 
    return FALSE;
  }
}
