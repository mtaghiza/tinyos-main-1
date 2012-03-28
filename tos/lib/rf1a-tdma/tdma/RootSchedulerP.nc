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
    S_OFF            = 0x00,
    S_SC_STARTING    = 0x01,

    S_BASELINE       = 0x02,
    S_ADJUSTING      = 0x03,
    S_CHECKING       = 0x04,
    S_FINALIZING     = 0x05,
    S_FINAL_CHECKING = 0x06,
    S_ESTABLISHED    = 0x07,

//    S_RESET_STOPPING,
//    S_RESET_STOPPED,
//    S_RESET_STARTING,
    S_RESETTING      = 0x08,

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
  
  //TODO:other stuff
  task void announceSchedule();

  //transition test functions
  bool disconnected();
  bool higherSRChecked();
  bool lowerMoreEfficient();
  bool maxSRKnown();

  //schedule announcement modification functions
  void resetNextSR(bool resetC, bool resetM);
  bool increaseNextSR();
  bool decreaseNextSR();
  void finalizeNextSR();
  void keepNextSR(bool increaseSN);
  void setupPacket(message_t* msg, 
      uint8_t sn, 
      uint16_t originalFrame, 
      uint16_t activeFrames, 
      uint16_t inactiveFrames, 
      uint16_t framesPerSlot, 
      uint8_t maxRetransmit, 
      uint8_t symbolRate, 
      uint8_t channel);

  //schedule modification functions
  void initializeSchedule();
  task void updateScheduleTask();
  void useNextSchedule();

  uint8_t totalNodes = TDMA_MAX_NODES - 1;

  enum {
    NUM_SRS= uniqueCount(SR_COUNT_KEY),
  };

  uint8_t state = S_OFF;
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
    if (state == S_OFF){
      error = call SubSplitControl.start();
      if (SUCCESS == error){
        printf_SCHED("SSC.s\r\n");
        state = S_SC_STARTING;
      }
    }
    return error;
  }

  event void SubSplitControl.startDone(error_t error){
    printf_SCHED("ssc.sd\r\n");
    if (state == S_SC_STARTING){
      if (SUCCESS == error){
        initializeSchedule();
        state = S_BASELINE;
        post announceSchedule();
      } else {
        printf("SSC.sd error %s\r\n", decodeError(error));
      }
      signal SplitControl.startDone(error);
    } else {
      printf("unexpected state %x at ssc.startdone\r\n", state);
    }
  }

  //we always announce the *next* schedule. In the steady-state, next
  //and current have the same contents.
  task void announceSchedule(){
    error_t error;
    if (state == S_BASELINE || state == S_ADJUSTING 
        || state == S_FINALIZING || state == S_RESETTING 
        || state == S_ESTABLISHED){
      //TODO: size, come on. the worst.
      if (SUCCESS == call AnnounceSend.send(next_schedule_msg,
          sizeof(cx_schedule_t) + sizeof(rf1a_nalp_am_t))){
        cx_schedule_t* ns = (cx_schedule_t*)(call
          Packet.getPayload(next_schedule_msg,
          sizeof(cx_schedule_t)));
        printf_SCHED("Announce Sending %p sn %u sr %u\r\n", 
          next_schedule_msg,
          ns->scheduleNum,
          ns->symbolRate);
        txState = S_SENDING;
      }else{
        printf("announce schedule: %s\r\n", decodeError(error));
      }
    } else {
      printf("unexpected state %x in announceSchedule\r\n", state);
    }
  }

  event void AnnounceSend.sendDone(message_t* msg, error_t error){
    printf_SCHED("AS.sendDone\r\n");
    if (SUCCESS != error){
      printf("AS.send done: %s\r\n", decodeError(error));
    } else {
      if (state == S_BASELINE || state == S_ADJUSTING 
          || state == S_FINALIZING || state == S_RESETTING
          || state == S_ESTABLISHED){
        txState = S_WAITING;
        if (state == S_BASELINE){
          //no change, but need to update schedule num.
          useNextSchedule();
        } else if (state == S_ADJUSTING){
          state = S_CHECKING;
          useNextSchedule();
        } else if (state == S_FINALIZING){
          state = S_FINAL_CHECKING;
          useNextSchedule();
        } else if (state == S_RESETTING){
          state = S_BASELINE;
          useNextSchedule();
        }
        //ESTABLISHED: no change.
        printf_SCHED("AS.sd: %lu\r\n", call CXPacket.getTimestamp(msg));
      } else {
        printf("Unexpected state %x in as.sendDone\r\n", state);
      }
    }
  }

  async event void FrameStarted.frameStarted(uint16_t frameNum){

    if ((1+frameNum)%(curSchedule->activeFrames + curSchedule->inactiveFrames) == (TDMA_ROOT_FRAMES_PER_SLOT*TOS_NODE_ID)){
      txState = S_NOT_SENT;

      if (state != S_ESTABLISHED){
        printf_SCHED_SR("fs");
      }

      //BASELINE: 
      // - disconnected: stay in baseline until everybody shows up
      //   (BASELINE)
      // - connected:
      //   - sr discovered: announce it (FINALIZING)
      //   - sr unknown: baseline +1 and announce (ADJUSTING)
      if (state == S_BASELINE){
        printf_SCHED_SR("b");
        if (disconnected()){
          printf_SCHED_SR("d");
          keepNextSR(TRUE);
        }else {
          if (maxSRKnown()){
            printf_SCHED_SR("f");
            state = S_FINALIZING;
            finalizeNextSR();
          } else {
            if (increaseNextSR()){
              printf_SCHED_SR("^");
              state = S_ADJUSTING;
            } else {
              printf_SCHED_SR("=");
              state = S_ESTABLISHED;
              keepNextSR(FALSE);
            }
          }
        }

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
          state = S_RESETTING;
          resetNextSR(TRUE, FALSE);

        // - connected, but last setting was more efficient: adjust
        //   next schedule and announce it (FINALIZING) 
        } else if (lowerMoreEfficient()){
          printf_SCHED_SR("V");
          decreaseNextSR();
          maxSR = nextSR;
          srState = S_DISCOVERED;
          state = S_FINALIZING;

        // - higher sr is also connected, but not as efficient
        //   (ESTABLISHED)
        } else if (higherSRChecked()){
          printf_SCHED_SR("=");
          srState = S_DISCOVERED;
          maxSR = curSR;
          keepNextSR(FALSE);
          state = S_ESTABLISHED;

        // - next sr up may be more efficient, so try it (ADJUSTING)
        } else {
          printf_SCHED_SR("^");
          increaseNextSR();
          state = S_ADJUSTING;
        }

      //FINAL_CHECKING: we were all synched up, then announced a new
      //symbol rate (which we intend to keep as the final SR). 
      } else if (state == S_FINAL_CHECKING){
        printf_SCHED_SR("C");
        // - got all the replies we expected, so call it quits.
        //   (ESTABLISHED)
        if (!disconnected()){
          printf_SCHED_SR("=");
          keepNextSR(FALSE);
          state = S_ESTABLISHED;

        //Disconnected, so try it again from the top :( (BASELINE)
        } else {
          printf_SCHED_SR("d!");
          state = S_RESETTING;
          resetNextSR(TRUE, TRUE);
        }

      //ESTABLISHED: keep same symbol rate, don't change schedule
      //  number.
      } else if (state == S_ESTABLISHED){
        printf_SCHED_SR("=");
        keepNextSR(FALSE);
      }
      printf_SCHED_SR("\r\n");
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
    printf("Unknown sr: %u\r\n", symbolRate);
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

  //Schedule modification functions
  void initializeSchedule(){
    //configure the uninitialized fields in curSchedule
    curSchedule = (cx_schedule_t*)(call Packet.getPayload(cur_schedule_msg,
      sizeof(cx_schedule_t)));
    curSchedule->scheduleNum = 0;
    curSchedule->channel = TEST_CHANNEL;
    //initialize nextSchedule
    resetNextSR(TRUE, TRUE);
    //this timestamp will be fed to the phy scheduler.
    call CXPacket.setTimestamp(next_schedule_msg, 
      call TDMAPhySchedule.getNow());
    //post task to start lower layer and swap cur with next
    useNextSchedule();
    //set up next identical to this one 
    keepNextSR(FALSE);
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

  void useNextSchedule(){
    message_t* swp = cur_schedule_msg;
    lastSR = curSchedule->symbolRate;
    cur_schedule_msg = next_schedule_msg;
    curSchedule = (cx_schedule_t*) call Packet.getPayload(cur_schedule_msg, sizeof(cx_schedule_t));
    next_schedule_msg = swp;
    psState = S_SWITCH_PENDING;
    post updateScheduleTask();
  }

  //Tests
  bool disconnected(){
    return nodesReachable[srIndex(curSchedule->symbolRate)] != totalNodes;
  }

  bool higherSRChecked(){
    return (maxDepth[srIndex(curSR)+1] != 0xff);
  }

  bool lowerMoreEfficient(){
    uint8_t lastDepth = maxDepth[srIndex(lastSR)];
    uint8_t curDepth = maxDepth[srIndex(curSR)];
//    printf_SCHED_SR("last %u cur %u: %u *%u < %u * %u\r\n",
//      lastSR, curSR, curSR, lastDepth, lastSR, curDepth);
    //TRUE: lastDepth/lastSR < curDepth/curSR
    return curSR * lastDepth < lastSR * curDepth;
  }
  
  bool maxSRKnown(){
    return srState == S_DISCOVERED;
  }


  //Schedule announcement modification functions
  void resetCounts(){
    uint8_t i;
    for(i = 0 ; i<NUM_SRS; i++){
      maxDepth[i] = 0xff;
      nodesReachable[i] = 0;
    }
  }

  void resetMaxSR(){
    srState = S_UNKNOWN;
    maxSR = 0;
  }

  void resetNextSR(bool resetC, bool resetM){
    setupPacket(next_schedule_msg,
      (curSchedule->scheduleNum+1)%0xff,
      TDMA_ROOT_FRAMES_PER_SLOT*TOS_NODE_ID,
      TDMA_ROOT_ACTIVE_FRAMES, 
      TDMA_ROOT_INACTIVE_FRAMES,
      TDMA_ROOT_FRAMES_PER_SLOT,
      TDMA_MAX_RETRANSMIT,
      TDMA_INIT_SYMBOLRATE,
      curSchedule->channel
    );
    if (resetC){
      resetCounts();
    }
    if (resetM){
      resetMaxSR();
    }
  }

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

  void keepNextSR(bool increaseSN){
    uint8_t nextSN;
    if (increaseSN){
      nextSN = (curSchedule->scheduleNum+1)%0xff;
    } else {
      nextSN = curSchedule->scheduleNum;
    }
    setupPacket(next_schedule_msg,
      nextSN,
      TDMA_ROOT_FRAMES_PER_SLOT*TOS_NODE_ID,
      TDMA_ROOT_ACTIVE_FRAMES, 
      TDMA_ROOT_INACTIVE_FRAMES,
      TDMA_ROOT_FRAMES_PER_SLOT,
      TDMA_MAX_RETRANSMIT,
      curSchedule->symbolRate,
      curSchedule->channel
    );
    printf_SCHED_SR("KN %p sr %u\r\n", next_schedule_msg,
      ((cx_schedule_t*)(call Packet.getPayload(next_schedule_msg,
      sizeof(cx_schedule_t))))->symbolRate);
  }

  //general packet setup
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

  //utilities
  task void printSchedule(){
    printf_SCHED_SR("sn %u of %u fl %lu fw %lu af %u if %u fps %u mr %u sr %u chan %u\r\n", 
      curSchedule->scheduleNum, curSchedule->originalFrame, curSchedule->frameLen,
      curSchedule->fwCheckLen, curSchedule->activeFrames, 
      curSchedule->inactiveFrames, curSchedule->framesPerSlot, 
      curSchedule->maxRetransmit, curSchedule->symbolRate,
      curSchedule->channel);
  }
  
  //TODO: split control
  command error_t SplitControl.stop(){
    return call SubSplitControl.stop();
  }
  event void SubSplitControl.stopDone(error_t error){
    signal SplitControl.stopDone(error);
  }

  //unused
  event void ReplySend.sendDone(message_t* msg, error_t error){}
  event message_t* AnnounceReceive.receive(message_t* msg, 
      void* payload, uint8_t len){
    return msg; 
  }
  async event void TDMAPhySchedule.frameStarted(uint32_t startTime, 
      uint16_t frameNum){ }

}
