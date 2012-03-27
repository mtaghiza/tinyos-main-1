 #include "schedule.h"
 #include "SchedulerDebug.h"
module RootSchedulerP{
  provides interface SplitControl;
  provides interface TDMARoutingSchedule[uint8_t rm];
  uses interface FrameStarted;

  uses interface SplitControl as SubSplitControl;
  uses interface TDMAPhySchedule;

  uses interface Send as AnnounceSend;
  uses interface Receive as AnnounceReceive;
  uses interface Send as ReplySend;
  uses interface Receive as ReplyReceive;

  uses interface Packet;
  uses interface CXPacket;
  uses interface CXRoutingTable;
  uses interface CXPacketMetadata;
  //maybe this should be done by Flood send.
  uses interface AMPacket;
} implementation {

  enum {
    S_BASELINE       = 0x01,
    S_ADJUSTING      = 0x02,
    S_CHECKING       = 0x03,
    S_FINALIZING     = 0x04,
    S_FINAL_CHECKING = 0x05,
    S_ESTABLISHED    = 0x06,
  };

  enum {
    S_NOT_SENT = 0x00,
    S_SENDING  = 0x01,
    S_WAITING  = 0x02,
  };

  enum {
    S_UNKNOWN    = 0x00,
    S_DISCOVERED = 0x01,
  };

  enum{
    S_SET            = 0x00,
    S_SWITCH_PENDING = 0x01,
  };

  uint8_t totalNodes = TDMA_MAX_NODES - 1;

  enum {
    NUM_SRS= uniqueCount(SR_COUNT_KEY),
  };

  uint8_t state = S_BASELINE;
  uint8_t txState = S_NOT_SENT;
  uint8_t srState = S_UNKNOWN;
  uint8_t psState = S_SWITCH_PENDING;
  uint8_t lastSR = 0;
  uint8_t curSR = 0;
  uint8_t nextSR = 0;
  uint8_t maxSR = 0;
  uint8_t nextBLSN = 0;
  bool resetBL = TRUE;
  bool blPending = FALSE;

  uint8_t symbolRates[10] = {
    1,
    2,
    5,
    10,
    39,
    77,
    100,
    125,
    175,
    250
  };

  uint32_t frameLens[10] = {
    (DEFAULT_TDMA_FRAME_LEN*125UL)/1UL,
    (DEFAULT_TDMA_FRAME_LEN*125UL)/2UL,
    (DEFAULT_TDMA_FRAME_LEN*125UL)/5UL,
    (DEFAULT_TDMA_FRAME_LEN*125UL)/10UL,
    (DEFAULT_TDMA_FRAME_LEN*125UL)/39UL,
    (DEFAULT_TDMA_FRAME_LEN*125UL)/77UL,
    (DEFAULT_TDMA_FRAME_LEN*125UL)/100UL,
    (DEFAULT_TDMA_FRAME_LEN*125UL)/125UL,
    (DEFAULT_TDMA_FRAME_LEN*125UL)/175UL,
    (DEFAULT_TDMA_FRAME_LEN*125UL)/250UL, 
  };

  uint32_t fwCheckLens[10] = {
    (DEFAULT_TDMA_FW_CHECK_LEN*125UL)/1UL,
    (DEFAULT_TDMA_FW_CHECK_LEN*125UL)/2UL,
    (DEFAULT_TDMA_FW_CHECK_LEN*125UL)/5UL,
    (DEFAULT_TDMA_FW_CHECK_LEN*125UL)/10UL,
    (DEFAULT_TDMA_FW_CHECK_LEN*125UL)/39UL,
    (DEFAULT_TDMA_FW_CHECK_LEN*125UL)/77UL,
    (DEFAULT_TDMA_FW_CHECK_LEN*125UL)/100UL,
    (DEFAULT_TDMA_FW_CHECK_LEN*125UL)/125UL,
    (DEFAULT_TDMA_FW_CHECK_LEN*125UL)/175UL,
    (DEFAULT_TDMA_FW_CHECK_LEN*125UL)/250UL, 
  };

  uint16_t nodesReachable[10]; 
  uint8_t maxDepth[10]; 

  #if defined (TDMA_MAX_NODES) && defined (TDMA_MAX_DEPTH) && defined (TDMA_MAX_RETRANSMIT)
  #define TDMA_ROOT_FRAMES_PER_SLOT (TDMA_MAX_DEPTH + TDMA_MAX_RETRANSMIT)
  #define TDMA_ROOT_ACTIVE_FRAMES (TDMA_MAX_NODES * TDMA_ROOT_FRAMES_PER_SLOT)
  #define TDMA_ROOT_INACTIVE_FRAMES (TDMA_MAX_NODES * TDMA_ROOT_FRAMES_PER_SLOT) 
  #else
  #error Must define TDMA_MAX_NODES, TDMA_MAX_DEPTH, and TDMA_MAX_RETRANSMIT
  #endif

  message_t cur_schedule_msg_internal;
  message_t* cur_schedule_msg = &cur_schedule_msg_internal;
  cx_schedule_t* curSchedule;

  message_t next_schedule_msg_internal;
  message_t* next_schedule_msg = &next_schedule_msg_internal;
  cx_schedule_t* nextSchedule;

  void reset();
  uint8_t srIndex(uint8_t sr);
  void useNextSchedule();

  command error_t SplitControl.start(){
    error_t error;
    error = call SubSplitControl.start();
    if (SUCCESS == error){
      printf_SCHED("SSC.sd\r\n");
      reset();
    }
    printf_SCHED("SC.s\r\n");
    return error;
  }

  void setupPacket(message_t* msg, 
      uint8_t sn, 
      uint16_t originalFrame, 
      uint16_t activeFrames, 
      uint16_t inactiveFrames, 
      uint16_t framesPerSlot, 
      uint8_t maxRetransmit, 
      uint8_t symbolRate, 
      uint8_t channel){
    cx_schedule_t* schedule; 
    call CXPacket.init(msg);

    call AMPacket.setDestination(msg, AM_BROADCAST_ADDR);
    call CXPacket.setDestination(msg, AM_BROADCAST_ADDR);
    schedule = (cx_schedule_t*)call Packet.getPayload(msg, sizeof(cx_schedule_t));
    schedule -> originalFrame = originalFrame;
    schedule -> frameLen = frameLens[srIndex(symbolRate)];
    schedule -> fwCheckLen = fwCheckLens[srIndex(symbolRate)];
    schedule -> activeFrames = activeFrames;
    schedule -> inactiveFrames = inactiveFrames;
    schedule -> framesPerSlot = framesPerSlot;
    schedule -> maxRetransmit = maxRetransmit;
    schedule -> symbolRate = symbolRate;
    schedule -> channel = channel;
    schedule -> scheduleNum = sn;
  }
  task void announceSchedule();

  task void printSchedule(){
    printf_SCHED_SR("sn %u of %u fl %lu fw %lu af %u if %u fps %u mr %u sr %u chan %u\r\n", 
      curSchedule->scheduleNum, curSchedule->originalFrame, curSchedule->frameLen,
      curSchedule->fwCheckLen, curSchedule->activeFrames, 
      curSchedule->inactiveFrames, curSchedule->framesPerSlot, 
      curSchedule->maxRetransmit, curSchedule->symbolRate,
      curSchedule->channel);
  }

  void reset(){
    uint8_t i;
    for(i = 0 ; i<NUM_SRS; i++){
      maxDepth[i] = 0xff;
      nodesReachable[i] = 0;
    }
    srState = S_UNKNOWN;
    maxSR = 0;
  }

  error_t baseline(uint8_t scheduleNum, bool resetSchedule){ 
    error_t error = SUCCESS;
    state = S_BASELINE;
    txState = S_NOT_SENT;
    printf_SCHED_SR("Baseline\r\n");
    //set up current schedule and next schedule identically 
    setupPacket(cur_schedule_msg, scheduleNum,
      TDMA_ROOT_FRAMES_PER_SLOT*TOS_NODE_ID,
      TDMA_ROOT_ACTIVE_FRAMES, 
      TDMA_ROOT_INACTIVE_FRAMES,
      TDMA_ROOT_FRAMES_PER_SLOT,
      TDMA_MAX_RETRANSMIT,
      TDMA_INIT_SYMBOLRATE,
      TEST_CHANNEL);
    setupPacket(next_schedule_msg, scheduleNum,
      TDMA_ROOT_FRAMES_PER_SLOT*TOS_NODE_ID,
      TDMA_ROOT_ACTIVE_FRAMES, 
      TDMA_ROOT_INACTIVE_FRAMES,
      TDMA_ROOT_FRAMES_PER_SLOT,
      TDMA_MAX_RETRANSMIT,
      TDMA_INIT_SYMBOLRATE,
      TEST_CHANNEL);
    curSchedule = (cx_schedule_t*)(call Packet.getPayload(cur_schedule_msg,
      sizeof(cx_schedule_t)));
    if (resetSchedule){
      error = call TDMAPhySchedule.setSchedule(
        call TDMAPhySchedule.getNow(), 
        curSchedule->originalFrame,
        curSchedule->frameLen,
        curSchedule->fwCheckLen,
        curSchedule->activeFrames,
        curSchedule->inactiveFrames,
        curSchedule->symbolRate,
        curSchedule->channel);
    }
    if (SUCCESS == error){
      psState = S_SET;
    }
    return error;
  }

  event void SubSplitControl.startDone(error_t error){
    if (SUCCESS == error){
      error = baseline(0, TRUE);
      if (SUCCESS == error){
        post announceSchedule();
        post printSchedule();
        printf_SCHED("setSchedule OK\r\n");
      }else{
        printf("set next schedule: %s\r\n", decodeError(error));
      }
    }
    signal SplitControl.startDone(error);
  }
  

  //we always announce the *next* schedule. In the steady-state, next
  //and current have the same contents.
  task void announceSchedule(){
    error_t error;
    message_t* toSend;

    if (state == S_BASELINE){
      toSend = cur_schedule_msg; 
    } else if (state == S_ADJUSTING || state == S_FINALIZING){
      toSend = next_schedule_msg;
    } else {
      printf("Unexpected announce schedule state %x %x %x %x\r\n",
        state, txState, srState, psState);
    }
    //TODO: size, come on
    error = call AnnounceSend.send(toSend,
      sizeof(cx_schedule_t) + sizeof(rf1a_nalp_am_t));
    if (SUCCESS != error){
      printf("announce schedule: %s\r\n", decodeError(error));
    }else{
      txState = S_SENDING;
    }
  }

  event void AnnounceSend.sendDone(message_t* msg, error_t error){
    if (SUCCESS != error){
      printf("AS.send done: %s\r\n", decodeError(error));
    } else {
      txState = S_WAITING;
      if (state == S_ADJUSTING){
        state = S_CHECKING;
        psState = S_SWITCH_PENDING;
        useNextSchedule();
      } else if (state == S_FINALIZING){
        state = S_FINAL_CHECKING;
        psState = S_SWITCH_PENDING;
        useNextSchedule();
      }
      printf_SCHED("AS.sd: %lu\r\n", call CXPacket.getTimestamp(msg));
    }
  }

  command error_t SplitControl.stop(){
    return call SubSplitControl.stop();
  }

  event void SubSplitControl.stopDone(error_t error){
    signal SplitControl.stopDone(error);
  }

  async event void TDMAPhySchedule.frameStarted(uint32_t startTime, 
      uint16_t frameNum){ }

  

  bool increaseNextSR(){
    uint8_t curSRI = srIndex(curSchedule->symbolRate);
    //OK to increase if we will not exceed maximum-established symbol
    //rate.
    if ( curSRI < NUM_SRS - 1 ){
      setupPacket(next_schedule_msg,
        (curSchedule->scheduleNum+1)%0xff,
        TDMA_ROOT_FRAMES_PER_SLOT*TOS_NODE_ID,
        TDMA_ROOT_ACTIVE_FRAMES, 
        TDMA_ROOT_INACTIVE_FRAMES,
        TDMA_ROOT_FRAMES_PER_SLOT,
        TDMA_MAX_RETRANSMIT,
        symbolRates[curSRI + 1],
        curSchedule->channel
      );
      nextSR = ((cx_schedule_t*)
        (call Packet.getPayload(next_schedule_msg, sizeof(cx_schedule_t)))
        )->symbolRate;
      return TRUE;
    }else{
      //already at the maximum symbol rate.
      return FALSE;
    }
  }

  void finalizeNextSR(){
    setupPacket(next_schedule_msg,
      (curSchedule->scheduleNum+1)%0xff,
      TDMA_ROOT_FRAMES_PER_SLOT*TOS_NODE_ID,
      TDMA_ROOT_ACTIVE_FRAMES, 
      TDMA_ROOT_INACTIVE_FRAMES,
      TDMA_ROOT_FRAMES_PER_SLOT,
      TDMA_MAX_RETRANSMIT,
      maxSR,
      curSchedule->channel
    );
    nextSR = ((cx_schedule_t*)
      (call Packet.getPayload(next_schedule_msg, sizeof(cx_schedule_t)))
      )->symbolRate;
  }

  bool decreaseNextSR(){
    uint8_t curSRI = srIndex(curSchedule->symbolRate);
    //OK to decrease if we are not already at min 
    if ( curSRI > 0 ){
      setupPacket(next_schedule_msg,
        (curSchedule->scheduleNum+1)%0xff,
        TDMA_ROOT_FRAMES_PER_SLOT*TOS_NODE_ID,
        TDMA_ROOT_ACTIVE_FRAMES, 
        TDMA_ROOT_INACTIVE_FRAMES,
        TDMA_ROOT_FRAMES_PER_SLOT,
        TDMA_MAX_RETRANSMIT,
        symbolRates[curSRI - 1],
        curSchedule->channel
      );
      nextSR = ((cx_schedule_t*)
        (call Packet.getPayload(next_schedule_msg, sizeof(cx_schedule_t)))
        )->symbolRate;
      return TRUE;
    }else{
      //already at the minimum symbol rate.
      return FALSE;
    }
  }

  task void updateScheduleTask(){
    error_t error;
    printf_SCHED_SR("UST\r\n");
    error = call TDMAPhySchedule.setSchedule(
      call CXPacket.getTimestamp(cur_schedule_msg), 
      curSchedule->originalFrame,
      curSchedule->frameLen,
      curSchedule->fwCheckLen, 
      curSchedule->activeFrames,
      curSchedule->inactiveFrames, 
      curSchedule->symbolRate,
      curSchedule->channel
    );
    if (SUCCESS != error){
      printf("Unable to update schedule: %s\r\n", decodeError(error));
    } else {
      printf_SCHED_SR("UST OK\r\n");
      curSR = curSchedule->symbolRate;
      psState = S_SET;
    }
  }

  bool disconnected(){
    return nodesReachable[srIndex(curSchedule->symbolRate)] != totalNodes;
  }

  bool nextSRKnown(){
    return (maxDepth[srIndex(nextSR)] != 0xff);
  }

  bool lastMoreEfficient(){
    //TRUE: lastDepth/lastSR < curDepth/curSR
    return lastSR * maxDepth[srIndex(lastSR)] < curSR *
      maxDepth[srIndex(curSR)];
  }

  void useNextSchedule(){
    message_t* swp = cur_schedule_msg;
    lastSR = curSchedule->symbolRate;
    cur_schedule_msg = next_schedule_msg;
    curSchedule = (cx_schedule_t*) call Packet.getPayload(cur_schedule_msg, sizeof(cx_schedule_t));
    next_schedule_msg = swp;
    psState = S_SWITCH_PENDING;
    post updateScheduleTask();
  }

  task void baselineTask(){
    error_t error = baseline(nextBLSN, resetBL);
    if (SUCCESS == error){
      blPending = FALSE;
    }else{
      printf("Baseline failed: %s\r\n", decodeError(error));
    }
  }

  bool postBaseline(bool resetSchedule){
    if (blPending){
      return FALSE;
    }else{
      nextBLSN = (curSchedule->scheduleNum +1)%0xff;
      resetBL = resetSchedule;
      blPending = TRUE;
      post baselineTask();
      return TRUE;
    }
  }

  async event void FrameStarted.frameStarted(uint16_t frameNum){
    txState = S_NOT_SENT;

    if ((1+frameNum)%(curSchedule->activeFrames + curSchedule->inactiveFrames) == (TDMA_ROOT_FRAMES_PER_SLOT*TOS_NODE_ID)){
      printf_SCHED_SR("fs");
      //BASELINE: 
      // - disconnected: stay in baseline until everybody shows up
      //   (BASELINE)
      // - connected:
      //   - sr discovered: announce it (FINALIZING)
      //   - sr unknown: baseline +1 and announce (ADJUSTING)
      if (state == S_BASELINE){
        printf_SCHED_SR("b");
        //TODO: REMOVE DEBUG CODE: stay in baseline
//        if (!disconnected()){
        if (FALSE){
          if (srState == S_UNKNOWN){
            if (increaseNextSR()){
              printf_SCHED_SR("i");
              state = S_ADJUSTING;
            } else {
              printf("error: couldn't increase SR from baseline state?!\r\n");
            }
          } else {
            printf_SCHED_SR("f");
            state = S_FINALIZING;
            finalizeNextSR();
          }
        } else {
          printf_SCHED_SR("d");
          if (!postBaseline(FALSE)){
            printf("BL->BL: Busy!\r\n");
          }
        }

//      //ADJUSTING:
//      // - update phy schedule, wait for responses (CHECKING)
//      } else if (state == S_ADJUSTING){
//        state = S_CHECKING;
//        psState = S_SWITCH_PENDING;
//        useNextSchedule();
//
      //CHECKING: look at replies from last round and adjust, reset,
      //or stand pat depending on result.
      } else if (state == S_CHECKING){
        printf_SCHED_SR("c");
        // - disconnected: last used is max SR, sr discovered, go back
        //   to baseline and wait for everybody. (BASELINE)
        if (disconnected()){
          printf_SCHED_SR("d");
          maxSR = lastSR;
          srState = S_DISCOVERED;
          if (!postBaseline(TRUE)){
            printf("CHECK->BL: Busy!\r\n");
          }

        // - connected, but last setting was more efficient: adjust
        //   next schedule and announce it (FINALIZING) 
        } else if (lastMoreEfficient()){
          printf_SCHED_SR("V");
          decreaseNextSR();
          maxSR = nextSR;
          srState = S_DISCOVERED;
          state = S_FINALIZING;

        // - next sr up is also connected, but not as efficient
        //   (ESTABLISHED)
        } else if (nextSRKnown()){
          printf("=");
          srState = S_DISCOVERED;
          maxSR = curSR;
          state = S_ESTABLISHED;

        // - next sr up may be more efficient, so try it (ADJUSTING)
        } else {
          printf_SCHED_SR("^");
          increaseNextSR();
          state = S_ADJUSTING;
        }

//      //FINALIZING: we think we're good to go, but we did just
//      //announce a new symbol rate. So, let's listen for replies
//      //(FINAL_CHECKING)
//      } else if (state == S_FINALIZING){
//        state = S_FINAL_CHECKING;
//        psState = S_SWITCH_PENDING;
//        useNextSchedule();
//
      //FINAL_CHECKING: we were all synched up, then announced a new
      //symbol rate (which we intend to keep as the final SR). 
      } else if (state == S_FINAL_CHECKING){
        printf("C");
        // - got all the replies we expected, so call it quits.
        //   (ESTABLISHED)
        if (!disconnected()){
          printf("=");
          state = S_ESTABLISHED;

        //Disconnected, so try it again from the top :( (BASELINE)
        } else {
          printf("d!");
          reset();
          if (! postBaseline(TRUE)){
            printf("FINALCHECK->BL: Busy!\r\n");
          }
        }
      }
      printf("\r\n");
      post announceSchedule();
    }
  }

  async event int32_t TDMAPhySchedule.getFrameAdjustment(uint16_t frameNum){
    //as root, we let the rest of the network adjust around us.
    return 0;
  }

  async command uint16_t TDMARoutingSchedule.framesPerSlot[uint8_t rm](){
    return curSchedule->framesPerSlot;
  }
  
  //as root: we are origin for floods during frame 0. Other frames?
  //defer to AODV.
  async command bool TDMARoutingSchedule.isOrigin[uint8_t rm](uint16_t frameNum){
    if (frameNum == 0 && rm == CX_RM_FLOOD){
      return TRUE;
    }else {
      return FALSE;
    }
  }
  
  //always in synch, so ok to forward.
  async command bool TDMARoutingSchedule.isSynched[uint8_t rm](uint16_t frameNum){
    return TRUE;
  }

  async command uint8_t TDMARoutingSchedule.maxRetransmit[uint8_t rm](){
    return curSchedule->maxRetransmit;
  }
  
  //argh i don't see a way around doing this.
  uint8_t srIndex(uint8_t symbolRate){
    uint8_t i;
    for (i = 0; i < NUM_SRS; i++){
      if (symbolRates[i] == symbolRate){
        return i;
      }
    }
    return 0xff;
  }

  event message_t* ReplyReceive.receive(message_t* msg, void* payload,
      uint8_t len){
    uint8_t curSRI = srIndex(curSchedule->symbolRate);
    uint8_t receivedCount = call CXPacketMetadata.getReceivedCount(msg);
    cx_schedule_reply_t* reply = (cx_schedule_reply_t*)payload;
    printf_SCHED_SR("reply.rx: %x %d (sn %u)\r\n", call CXPacket.source(msg), 
      call CXRoutingTable.distance(call CXPacket.source(msg), TOS_NODE_ID),
      reply->scheduleNum);

    if ((state == S_BASELINE || state == S_CHECKING 
      || state == S_FINAL_CHECKING)
        && (reply->scheduleNum == curSchedule->scheduleNum)){
      nodesReachable[curSRI]++;
      maxDepth[curSRI] = 
        (maxDepth[curSRI] != 0xff && maxDepth[curSRI] > receivedCount)? maxDepth[curSRI] : receivedCount;
      printf_SCHED_SR("sr %u (%u = %u) nr %u md %u\r\n",
        curSchedule->scheduleNum, curSchedule->scheduleNum, curSRI, nodesReachable[curSRI],
        maxDepth[curSRI]);
    } else {
      printf("Unexpected reply.rx: state: %x src %x (sn: %u) cur sched: %u\r\n", 
        state, call CXPacket.source(msg), reply->scheduleNum, 
        curSchedule->scheduleNum);
    }
    return msg;
  }

  //unused
  event void ReplySend.sendDone(message_t* msg, error_t error){}
  event message_t* AnnounceReceive.receive(message_t* msg, 
      void* payload, uint8_t len){
    return msg; 
  }
}
