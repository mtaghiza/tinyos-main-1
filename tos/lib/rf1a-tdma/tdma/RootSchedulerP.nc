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
    S_BASELINE,
    S_ADJUSTING,
    S_CHECKING,
    S_FINALIZING,
    S_FINAL_CHECKING,
    S_ESTABLISHED,
  };

  enum {
    S_NOT_SENT,
    S_SENDING,
    S_WAITING,
  };

  enum {
    S_UNKNOWN,
    S_DISCOVERED,
  };

  enum{
    S_SET,
    S_SWITCH_PENDING,
  };

  uint8_t totalNodes = TDMA_MAX_NODES;

  enum {
    NUM_SRS= uniqueCount(SR_COUNT_KEY),
  };

  uint8_t state = S_BASELINE;
  uint8_t txState = S_NOT_SENT;
  uint8_t srState = S_UNKNOWN;
  uint8_t psState = S_SET;

  bool repliesPending;

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

  uint16_t frameLens[10] = {
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

  uint16_t fwCheckLens[10] = {
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

  uint16_t nodesReachable[10]; 
  uint8_t maxDepth[10]; 
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
    uint8_t i;
    error = call SubSplitControl.start();
    if (SUCCESS == error){
      for(i = 0 ; i<NUM_SRS; i++){
        maxDepth[i] = 0;
        nodesReachable[i] = 0;
      }
      printf_SCHED("SSC.sd\r\n");
      scheduleNum = 0;

    }
    printf_SCHED("SC.s\r\n");
    return error;
  }

  void setupPacket(message_t* msg, uint8_t sn, uint16_t originalFrame, 
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
    schedule -> scheduleNum = sn;
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

  void reset(){
    srState = S_UNKNOWN;
  }

  error_t baseline(){ 
    state = S_BASELINE;
    txState = S_NOT_SENT;
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
    error = call TDMAPhySchedule.setSchedule(
      call TDMAPhySchedule.getNow(), 
      curSchedule->originalFrame,
      curSchedule->frameLen,
      curSchedule->fwCheckLen,
      curSchedule->activeFrames,
      curSchedule->inactiveFrames,
      curSchedule->symbolRate,
      curSchedule->channel);

    return error;
  }

  event void SubSplitControl.startDone(error_t error){
    if (SUCCESS == error){
      error = baseline();
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
    } else {
      printf("Unexpected announce schedule state %x\r\n", state);
    }
    error = call AnnounceSend.send(toSend,
      sizeof(cx_schedule_t));
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

  bool increaseSymbolRate(){
    //OK to increase if we will not exceed maximum-established symbol
    //rate.
    if (curSRI < maxSRI  && curSRI < NUM_SRS - 1 ){
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
  // - in the case of network disconnection, go back to baseline and
  //   wait until all are reconnected, then switch to fastest safe symbol
  //   rate.
  // - non-root: if you go n cycles without getting a schedule, go
  //   back to the baseline symbol rate.
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

    //last increase led to disconnection. Reset symbol rate to
    //baseline.
    if (nodesReachable[lastSRI] > nodesReachable[curSRI]){
      maxSRI = lastSRI;
      resetSymbolRate();
      return TRUE;
    }

    //check for efficiency change.
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

  task void updateScheduleTask(){
    error_t error;
    //TODO: what is startTS exactly? may have to get this from the
    //TDMAPhySchedule (something like, nextScheduledFS command)
    error = call TDMAPhySchedule.setSchedule(startTS,
      TDMA_ROOT_FRAMES_PER_SLOT*TOS_NODE_ID,
      curSchedule->frameLen,
      curSchedule->frameLen,
      curSchedule->fwCheckLen, 
      curSchedule->activeFrames,
      curSchedule->inactiveFrames, 
      curSchedule->symbolRate,
      curSchedule->channel
    );
    curSRI = srIndex(curSchedule->symbolRate);
    if (SUCCESS != error){
      printf("Unable to update schedule: %s\r\n", decodeError(error));
    } else {
      if (state == S_ADJUST_WAIT){
        state = S_COLLECT_NEXT;
      } else if (state == S_COLLECT_WAIT){
        state = S_RECONNECT_NEXT;
      }
    }
  }

  async event void FrameStarted.frameStarted(uint16_t frameNum){
    txState = S_NOT_SENT;

    if ((1+frameNum)%(curSchedule->activeFrames + curSchedule->inactiveFrames) == (TDMA_ROOT_FRAMES_PER_SLOT*TOS_NODE_ID)){
      //BASELINE: 
      // - disconnected: stay in baseline until everybody shows up
      //   (BASELINE)
      // - connected:
      //   - sr discovered: announce it (FINALIZING)
      //   - sr unknown: baseline +1 and announce (ADJUSTING)
      if (state == S_BASELINE){
        if (!disconnected()){
          if (srState == S_UNKNOWN){
            state = S_ADJUSTING;
            increaseNextSR();
          } else {
            state = S_FINALIZING;
            finalizeNextSR();
          }
        } else {
          scheduleNum ++;
          baseline();
        }

      //ADJUSTING:
      // - update phy schedule, wait for responses (CHECKING)
      } else if (state == S_ADJUSTING){
        state = S_CHECKING;
        psState = S_SWITCH_PENDING;
        useNextSchedule();

      //CHECKING: look at replies from last round and adjust, reset,
      //or stand pat depending on result.
      } else if (state == S_CHECKING){
        scheduleNum++;
        // - disconnected: last used is max SR, sr discovered, go back
        //   to baseline and wait for everybody. (BASELINE)
        if (disconnected()){
          maxSR = lastSR;
          srState = S_DISCOVERED;
          baseline();

        // - connected, but last setting was more efficient: adjust
        //   next schedule and announce it (FINALIZING) 
        } else if (lastMoreEfficient()){
          decreaseNextSR();
          maxSR = nextSR;
          srState = S_DISCOVERED;
          state = S_FINALIZING;

        // - next sr up is also connected, but not as efficient
        //   (ESTABLISHED)
        } else if (nextSRKnown()){
          srState = S_DISCOVERED;
          maxSR = currentSR;
          state = S_ESTABLISHED;

        // - next sr up may be more efficient, so try it (ADJUSTING)
        } else {
          increaseNextSr();
          state = S_ADJUSTING;
        }

      //FINALIZING: we think we're good to go, but we did just
      //announce a new symbol rate. So, let's listen for replies
      //(FINAL_CHECKING)
      } else if (state == S_FINALIZING){
        state = S_FINAL_CHECKING;
        psState = S_SWITCH_PENDING;
        useNextSchedule();

      //FINAL_CHECKING: we were all synched up, then announced a new
      //symbol rate (which we intend to keep as the final SR). 
      } else if (state == S_FINAL_CHECKING){
        // - got all the replies we expected, so call it quits.
        //   (ESTABLISHED)
        if (!disconnected()){
          state = S_ESTABLISHED;

        //Disconnected, so try it again from the top :( (BASELINE)
        } else {
          scheduleNum++;
          reset();
          baseline();
        }
      }

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
    cx_schedule_reply_t* reply = (cx_schedule_reply_t*)msg;
    printf_SCHED("reply.rx: %x %d (sn %u)\r\n", call CXPacket.source(msg), 
      call CXRoutingTable.distance(call CXPacket.source(msg), TOS_NODE_ID),
      reply->scheduleNum);

    if ((state == S_BASELINE)
        && (reply->scheduleNum == curSchedule->scheduleNum)){
      nodesReachable[curSRI]++;
      maxDepth[curSRI] = 
        (maxDepth[curSRI] > receivedCount)? maxDepth[curSRI] : receivedCount;
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
