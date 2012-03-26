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

  enum{
    S_ADJUST_NEXT,
    S_ADJUST_ANNOUNCING,
    S_ADJUST_WAIT,
    S_COLLECT_NEXT,
    S_COLLECT_ANNOUNCING,
    S_COLLECTING,
    S_IDLE,
    S_IDLE_ANNOUNCING,
  };

  bool firstSR;
  bool hasDecreased;
  uint8_t lastSRI;

  enum {
    NUM_SRS= uniqueCount(SR_COUNT_KEY),
  };

  uint8_t state = S_OFF;
  bool repliesPending;

  uint8_t symbolRates[NUM_SRS] = {
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

  uint16_t frameLens[NUM_SRS] = {
    (DEFAULT_TDMA_FRAME_LEN*125)/1,
    (DEFAULT_TDMA_FRAME_LEN*125)/2,
    (DEFAULT_TDMA_FRAME_LEN*125)/5,
    (DEFAULT_TDMA_FRAME_LEN*125)/10,
    (DEFAULT_TDMA_FRAME_LEN*125)/39,
    (DEFAULT_TDMA_FRAME_LEN*125)/77,
    (DEFAULT_TDMA_FRAME_LEN*125)/100,
    (DEFAULT_TDMA_FRAME_LEN*125)/125,
    (DEFAULT_TDMA_FRAME_LEN*125)/175,
    (DEFAULT_TDMA_FRAME_LEN*125)/250, 
  };

  uint16_t fwCheckLens[NUM_SRS] = {
    (DEFAULT_TDMA_FW_CHECK_LEN*125)/1,
    (DEFAULT_TDMA_FW_CHECK_LEN*125)/2,
    (DEFAULT_TDMA_FW_CHECK_LEN*125)/5,
    (DEFAULT_TDMA_FW_CHECK_LEN*125)/10,
    (DEFAULT_TDMA_FW_CHECK_LEN*125)/39,
    (DEFAULT_TDMA_FW_CHECK_LEN*125)/77,
    (DEFAULT_TDMA_FW_CHECK_LEN*125)/100,
    (DEFAULT_TDMA_FW_CHECK_LEN*125)/125,
    (DEFAULT_TDMA_FW_CHECK_LEN*125)/175,
    (DEFAULT_TDMA_FW_CHECK_LEN*125)/250, 
  };

  uint16_t nodesReachable[NUM_SRS]; 
  uint8_t maxDepth[NUM_SRS]; 
  uint8_t scheduleNum = 0;

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

  command error_t SplitControl.start(){
    error_t error;
    for(uint8_t i = 0 ; i<NUM_SRS; i++){
      maxDepth[i] = 0;
      nodesReachable[i] = 0;
    }
    printf_SCHED("SC.s\r\n");
    error = call SubSplitControl.start();
    return error;
  }

  void setupPacket(message_t* msg, uint8_t scheduleNum, uint16_t originalFrame, 
      uint16_t activeFrames, 
      uint16_t inactiveFrames, uint16_t framesPerSlot, 
      uint8_t maxRetransmit, uint8_t symbolRate, uint8_t channel){
    cx_schedule_t* schedule; 
    call CXPacket.init(msg);

    call AMPacket.setDestination(msg, AM_BROADCAST_ADDR);
    call CXPacket.setDestination(msg, AM_BROADCAST_ADDR);
    schedule = (cx_schedule_t*)call Packet.getPayload(msg, sizeof(cx_schedule_t));
    schedule -> originalFrame = originalFrame;
    schedule -> frameLen = frameLens[symbolRate];
    schedule -> fwCheckLen = fwCheckLens[symbolRate];
    schedule -> activeFrames = activeFrames;
    schedule -> inactiveFrames = inactiveFrames;
    schedule -> framesPerSlot = framesPerSlot;
    schedule -> maxRetransmit = maxRetransmit;
    schedule -> symbolRate = symbolRate;
    schedule -> channel = channel;
    schedule -> scheduleNum = scheduleNum;
  }
  task void announceSchedule();

  task void printSchedule(){
    printf_SCHED_SR("sn %u of %u fl %lu fw %lu af %u if %u fps %u mr %u sr %u chan %u\r\n", 
      curSchedule->curScheduleNum, curSchedule->originalFrame, curSchedule->frameLen,
      curSchedule->fwCheckLen, curSchedule->activeFrames, 
      curSchedule->inactiveFrames, curSchedule->framesPerSlot, 
      curSchedule->maxRetransmit, curSchedule->symbolRate,
      curSchedule->channel);
  }

  event void SubSplitControl.startDone(error_t error){
    printf_SCHED("SSC.sd\r\n");
    state = S_COLLECT_NEXT;
    firstSR = TRUE;
    hasDecreased = FALSE;
    scheduleNum = 0;
    //set up current schedule and next schedule identically at first.
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
    curSchedule = (cx_schedule_t*)(call Packet.getPayload(msg,
      sizeof(cx_schedule_t)));
    if (SUCCESS == error){
      error = call TDMAPhySchedule.setSchedule(
        call TDMAPhySchedule.getNow(), 
        curSchedule->originalFrame,
        curSchedule->frameLen,
        curSchedule->fwCheckLen,
        curSchedule->activeFrames,
        curSchedule->inactiveFrames,
        curSchedule->symbolRate,
        curSchedule->channel);
      if (SUCCESS == error){
        //state: fixin' to announce.
        //set flag to indicate that we are waiting for replies.
//        post announceSchedule();
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
    if (state == S_BS_NEXT){
      toSend = next_schedule_msg;
    }else {
      toSend = cur_schedule_msg;
    }
    error = call AnnounceSend.send(toSend,
      sizeof(cx_schedule_t));
    if (SUCCESS != error){
      printf("announce schedule: %s\r\n", decodeError(error));
    }else{
      if (state == S_COLLECT_NEXT){
        state = S_COLLECT_ANNOUNCING;
      } else if (state == S_ADJUST_NEXT){
        state = S_ADJUST_ANNOUNCING;
      }else if (state == S_IDLE){
        state = S_IDLE_ANNOUNCING;
      }
    }
  }

  event void AnnounceSend.sendDone(message_t* msg, error_t error){
    if (SUCCESS != error){
      printf("AS.send done: %s\r\n", decodeError(error));
    } else {
      printf_SCHED("AS.sd: %lu\r\n", call CXPacket.getTimestamp(msg));
      if (state == S_IDLE_ANNOUNCING){
        state = S_IDLE;
      } else if (state == S_ADJUST_ANNOUNCING){
        state = S_ADJUST_WAIT;
      } else if (state == S_COLLECT_ANNOUNCING){
        state = S_COLLECTING;
      }
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

  bool increaseSymbolRate(){
    if (curSchedule->symbolRate != symbolRates[NUM_SRS-1]){
      setupPacket(next_schedule_msg,
        curSchedule->scheduleNum+1,
        TDMA_ROOT_FRAMES_PER_SLOT*TOS_NODE_ID,
        TDMA_ROOT_FRAMES_PER_SLOT*TOS_NODE_ID,
        TDMA_ROOT_ACTIVE_FRAMES, 
        TDMA_ROOT_INACTIVE_FRAMES,
        TDMA_ROOT_FRAMES_PER_SLOT,
        TDMA_MAX_RETRANSMIT,
        symbolRates[srIndex(curSchedule->symbolRate)+1],
        curSchedule->channel
      );
      return TRUE;
    }else{
      //already at the maximum symbol rate.
      return FALSE;
    }
  }

  bool decreaseSymbolRate(){
    if (curSchedule->symbolRate != symbolRates[0]){
      setupPacket(next_schedule_msg,
        curSchedule->scheduleNum+1,
        TDMA_ROOT_FRAMES_PER_SLOT*TOS_NODE_ID,
        TDMA_ROOT_FRAMES_PER_SLOT*TOS_NODE_ID,
        TDMA_ROOT_ACTIVE_FRAMES, 
        TDMA_ROOT_INACTIVE_FRAMES,
        TDMA_ROOT_FRAMES_PER_SLOT,
        TDMA_MAX_RETRANSMIT,
        symbolRates[srIndex(curSchedule->symbolRate)-1],
        curSchedule->channel
      );
      return TRUE;
    } else {
      //already at the minimum symbol rate.
      return FALSE;
    }
  }

  //bootstrapping-then-stable version:
  //start at baseline, increase until either the network is
  //disconnected or efficiency drops. 
  //TODO: would be nice to have this track with the network as time
  //goes on. Or failing that, periodically re-bootstrap the network.
  bool adjustSymbolRate(){
    //always increase from the first setting.
    if (firstSR){
      firstSR = FALSE;
      increaseSymbolRate();
      return TRUE;
    }
    //if we dropped down last round, then we're done.
    if (hasDecreased){
      return FALSE;
    }

    //last increase led to disconnection.
    if (nodesReachable[lastSRI] > nodesReachable[curSRI]){
      decreaseSymbolRate();
      return TRUE;
    }
    //lastDepth/lastSR < curDepth/curSR
    if (maxDepth[lastSRI]*symbolRates[curSRI] <
        maxDepth[curSRI]*symbolRates[lastSRI]){
      //last step was less efficient than this one, so increase the
      //symbol rate.
      return increaseSymbolRate();
    } else {
      //this sr is less efficient, so go back a step.
      decreaseSymbolRate();
      return TRUE;
    }
    
    return FALSE;
  }

  async event void FrameStarted.frameStarted(uint16_t frameNum){
    //may be off-by-one
    if ((1+frameNum)%(curSchedule->activeFrames + curSchedule->inactiveFrames) == (TDMA_ROOT_FRAMES_PER_SLOT*TOS_NODE_ID)){
      if (state == S_ADJUST_WAIT){
        message_t* swp = cur_schedule_msg;
        cur_schedule_msg = next_schedule_msg;
        next_schedule_msg = swp;
        //TODO: swap cur and next.
        //TODO: update schedule. Careful, this is coming from the PFS
        //event.
      }else if (state == S_COLLECTING){
        if (adjustSymbolRate()){
          state = S_ADJUST_NEXT;
        }else{
          //we're happy with things, so update curSchedule and we're
          //cool.
          memcpy(curSchedule, nextSchedule, sizeof(cx_schedule_t));
          state = S_IDLE;
        }
      }
//      printf_SCHED("post announce @%d\r\n", frameNum);
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
    for (uint8_t i; i < NUM_SRS; i++){
      if (symbolRates[i] == symbolRate){
        return i;
      }
    }
    return 0xff;
  }

  event message_t* ReplyReceive.receive(message_t* msg, void* payload,
      uint8_t len){
    uint8_t sri;
    uint8_t receivedCount = call CXPacketMetadata.receivedCount(msg);
    printf_SCHED("reply.rx: %x %d\r\n", call CXPacket.source(msg), 
      call CXRoutingTable.distance(call CXPacket.source(msg), TOS_NODE_ID));
    sri = srIndex(curSchedule->symbolRate);
    nodesReachable[sri]++;
    maxDepth[sri] = 
      (maxDepth[sri] > receivedCount)? maxDepth[sri] : receivedCount;
    return msg;
  }

  //unused
  event void ReplySend.sendDone(message_t* msg, error_t error){}
  event message_t* AnnounceReceive.receive(message_t* msg, 
      void* payload, uint8_t len){
    return msg; 
  }
}
