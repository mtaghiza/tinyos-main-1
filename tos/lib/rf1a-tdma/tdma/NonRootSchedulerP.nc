 #include "SchedulerDebug.h"
 #include "schedule.h"
module NonRootSchedulerP{
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
  uses interface CXPacketMetadata;
  //maybe this should be done by Flood send.
  uses interface AMPacket;

  uses interface CXRoutingTable;
} implementation {
  #if defined (TDMA_MAX_NODES) && defined (TDMA_MAX_DEPTH) && defined (TDMA_MAX_RETRANSMIT)
  #define TDMA_ROOT_FRAMES_PER_SLOT (TDMA_MAX_DEPTH + TDMA_MAX_RETRANSMIT)
  #define TDMA_ROOT_ACTIVE_FRAMES (TDMA_MAX_NODES * TDMA_ROOT_FRAMES_PER_SLOT)
  #define TDMA_ROOT_INACTIVE_FRAMES (TDMA_MAX_NODES * TDMA_ROOT_FRAMES_PER_SLOT) 
  #else
  #error Must define TDMA_MAX_NODES, TDMA_MAX_DEPTH, and TDMA_MAX_RETRANSMIT
  #endif
  
  //store current/next schedule as pointer to some received-schedule's
  //  payload.
  //This layer needs to have two message_t's then. When we receive a
  //  an announcement with a new schedule, we swap it with nextSched.
  //When we switch to a new schedule, we swap nextSched and curSched.
//  uint8_t scheduleCount = 0;

  message_t sched_1;
  message_t sched_2;
  message_t* curMsg = &sched_1;
  message_t* nextMsg = &sched_2;
  cx_schedule_t* curSched;

  message_t reply_msg_internal;
  message_t* replyMsg = &reply_msg_internal;

  uint16_t framesSinceLastSchedule = 2;
  uint16_t lastRxFrameNum;
  uint16_t lastFrameNum;
  uint32_t lastRxTS;
  uint32_t lastRootStart;

  int32_t ticksPerFrame;
  uint16_t extraFrames = 0;
  int32_t extraFrameOffset;
  int32_t endOfCycle;

  uint16_t cycleNum = 0;

  bool changePending;
  bool replyPending;
  bool startPending;

  #define DELTA_BUF_LEN 8
  int32_t delta[DELTA_BUF_LEN];

  command error_t SplitControl.start(){
    error_t error = call SubSplitControl.start();
    if (SUCCESS == error){
      startPending = TRUE;
    }
    return error;
  }

  //initialize curSched to try to catch a new schedule announcement.
  event void SubSplitControl.startDone(error_t error){
    curSched = (cx_schedule_t*)(call Packet.getPayload(curMsg, sizeof(cx_schedule_t)));
//    curSched -> frameLen = DEFAULT_TDMA_FRAME_LEN;
//    curSched -> fwCheckLen = DEFAULT_TDMA_FW_CHECK_LEN;
//    curSched -> activeFrames = TDMA_ROOT_ACTIVE_FRAMES;
//    curSched -> inactiveFrames = TDMA_ROOT_INACTIVE_FRAMES;
//    curSched -> symbolRate = TDMA_INIT_SYMBOLRATE;
//    curSched -> scheduleNum = 0xff;
//    curSched -> framesPerSlot = TDMA_ROOT_FRAMES_PER_SLOT;
//    curSched -> maxRetransmit = TDMA_MAX_RETRANSMIT;

    curSched -> frameLen = 10*DEFAULT_TDMA_FRAME_LEN;
    curSched -> fwCheckLen = 2*10*DEFAULT_TDMA_FRAME_LEN;
    curSched -> activeFrames = 1;
    curSched -> inactiveFrames = 0;
    curSched -> symbolRate = 0;
    curSched -> scheduleNum = 0xff;
    curSched -> framesPerSlot = 0;
    curSched -> maxRetransmit = 0;
    error = call TDMAPhySchedule.setSchedule(
      call TDMAPhySchedule.getNow(), 
      0, 
      curSched->frameLen,
      curSched->fwCheckLen, 
      curSched->activeFrames,
      curSched->inactiveFrames, 
      curSched->symbolRate);
    if (SUCCESS != error){
      printf("setSchedule: %s\r\n", decodeError(error));
    }else{
      printf_SCHED("ssc.sd setSchedule OK\r\n");
    }
  }

  task void printNext(){
    cx_schedule_t* pl = (cx_schedule_t*) call
    Packet.getPayload(nextMsg, sizeof(cx_schedule_t));
    printf_SCHED("sn %u of %u fl %lu fw %lu af %u if %u fps %u mr %u sr %u\r\n", 
      pl->scheduleNum, pl->originalFrame, pl->frameLen,
      pl->fwCheckLen, pl->activeFrames, pl->inactiveFrames,
      pl->framesPerSlot, pl->maxRetransmit, pl->symbolRate);
  }

  task void updateScheduleTask();
  //TODO: do we need to reset schedule more often?
  #define DEBUG_BREAK 51
  event message_t* AnnounceReceive.receive(message_t* msg, 
      void* payload, uint8_t len){
    cx_schedule_t* pl = (cx_schedule_t*) payload;
    uint32_t rxTS;
    uint32_t curRootStart;
    uint16_t rxFrameNum;
    printf_SCHED("AR.r ");

    //update clock skew figures 
    framesSinceLastSchedule = 0;

    rxFrameNum = pl->originalFrame 
      + call CXRoutingTable.distance(call CXPacket.source(msg), TOS_NODE_ID);  
    rxTS = call CXPacketMetadata.getReceivedAt(msg);
    curRootStart = call CXPacket.getTimestamp(msg);

    if (pl->scheduleNum == curSched->scheduleNum){
      printf_SCHED("s");
      if(lastRxTS != 0){
        uint32_t rootTicks;
        uint32_t myTicks;
        int32_t d;
        int32_t framesElapsed = 
          curSched->activeFrames+curSched->inactiveFrames;
        printf_SCHED("v");
        printf_SCHED("(%lu, %lu) -> (%lu, %lu) over %ld\r\n", 
          lastRxTS, lastRootStart, 
          rxTS, curRootStart,
          framesElapsed);
        rootTicks = curRootStart - lastRootStart;
        myTicks = rxTS - lastRxTS;
        d = myTicks - rootTicks;
        cycleNum++;
        cycleNum = (cycleNum)%DELTA_BUF_LEN;
        delta[cycleNum] = d;
        printf_SCHED(" %ld ", d);
        //TODO: double check this logic. 
        if ( d > framesElapsed ){
          //evenly distribute as much as possible
          ticksPerFrame = d/framesElapsed;
          //distribute leftovers over the rest of the frames as evenly
          //as possible. 
          d -= (ticksPerFrame*framesElapsed);
          if (d){
            extraFrames = framesElapsed/d;
            extraFrameOffset = 1;
            //If frameNum %extraFrames != 0, add another tick to the last
            //frame.
            endOfCycle = (framesElapsed % extraFrames)?1:0;
          }else{
            extraFrames = framesElapsed;
            extraFrameOffset = 0;
            endOfCycle = 0;
          }
        }else if ( d < -1*framesElapsed){
          //same but for negative ticks
          ticksPerFrame = -1* (d/framesElapsed);
          d -= (ticksPerFrame*framesElapsed);
          if (d){
            extraFrames = -1*(framesElapsed/d);
            extraFrameOffset = -1;
            endOfCycle = (framesElapsed % extraFrames)?-1:0;
          }else{
            extraFrames = framesElapsed;
            extraFrameOffset = 0;
            endOfCycle = 0;
          }
        }
      }else{
        printf_SCHED("~v");
      }
      lastRxTS = rxTS;
      lastRxFrameNum = rxFrameNum;
      lastRootStart = call CXPacket.getTimestamp(msg);
      printf_SCHED("\r\n");
      post updateScheduleTask();
      return msg; 
    } else {
      message_t* swp = nextMsg;
      printf_SCHED("n\r\n");
      changePending = TRUE;
      lastRxTS = rxTS;
      lastRxFrameNum = rxFrameNum;
      lastRootStart = call CXPacket.getTimestamp(msg);
      extraFrames = 1;
      extraFrameOffset = 0;
      endOfCycle = 0;
      //TODO: other values to reset?
      nextMsg = msg;
      post printNext();
      return swp;
    }
  }

  task void replyTask(){
    error_t error;
    cx_schedule_reply_t* reply = 
      (cx_schedule_reply_t*)call ReplySend.getPayload(replyMsg, sizeof(cx_schedule_reply_t));
    reply->scheduleNum = curSched->scheduleNum;
    error = call ReplySend.send(replyMsg, sizeof(replyMsg));
    if (SUCCESS == error){
      printf_SCHED("ReplySend.send OK\r\n");
    }else{
      printf("ReplySend: %s\r\n", decodeError(error));
    }
  }

  task void updateScheduleTask(){
    error_t error;
    printf_SCHED("UST");
    error = call TDMAPhySchedule.setSchedule(lastRxTS, 
      lastRxFrameNum,
      curSched->frameLen,
      curSched->fwCheckLen, 
      curSched->activeFrames,
      curSched->inactiveFrames, 
      curSched->symbolRate);
    if (changePending){
      lastRxTS = 0;
      lastRxFrameNum = 0;
      changePending = FALSE;
      replyPending = TRUE;
      post replyTask();
    }
    if (SUCCESS == error){
      printf_SCHED(" OK\r\n");

    }else{
      printf("NonRootSchedulerP.UST!%s", decodeError(error));
    }
  }

  async event void FrameStarted.frameStarted(uint16_t frameNum){
    framesSinceLastSchedule++;
//    printf_SCHED("fs.f %u ", frameNum);
    //may be off by one
    if (changePending && (frameNum + 1 ==
        (curSched->activeFrames+curSched->inactiveFrames))){
      error_t error;
      message_t* swp = curMsg;
//      printf_SCHED("c");
      curMsg = nextMsg;
      nextMsg = swp;
      curSched = (cx_schedule_t*) call Packet.getPayload(curMsg,
       sizeof(cx_schedule_t));
      post updateScheduleTask();
    }
//    //TODO: remove after done testing
//    if (frameNum == 3){
//      post updateScheduleTask();
//    }
//    printf_SCHED("\r\n");
  }

  event void ReplySend.sendDone(message_t* msg, error_t error){
    if (startPending){
      startPending = FALSE;
      signal SplitControl.startDone(SUCCESS);
    }    
    replyPending = FALSE;
  }

  command error_t SplitControl.stop(){
    return call SubSplitControl.stop();
  }

  event void SubSplitControl.stopDone(error_t error){
    signal SplitControl.stopDone(error);
  }

  async event void TDMAPhySchedule.frameStarted(uint32_t startTime, 
      uint16_t frameNum){
    lastFrameNum = frameNum;
  }
  
  //ticksPerFrame: applied to each frame
  //if we're on an extraFrames boundary, add or subtract another one
  //if this is the last frame of the cycle, add in whatever's left.
  async event int32_t TDMAPhySchedule.getFrameAdjustment(uint16_t frameNum){
//    return 0;
    return -1*(ticksPerFrame 
      + ((frameNum %extraFrames == 0)?extraFrameOffset:0)
      + ((frameNum == 
          (curSched->activeFrames + curSched->inactiveFrames -1))
          ? endOfCycle: 0));
  }

  //we are origin if reply needed and this is the start of our slot.
  async command bool TDMARoutingSchedule.isOrigin[uint8_t rm](uint16_t frameNum){
    printf_SCHED_IO("io: ");
    if ((rm == CX_RM_FLOOD) 
        && replyPending 
        && (frameNum == (TOS_NODE_ID * (curSched->framesPerSlot)))){
      printf_SCHED_IO("T\r\n");
      return TRUE;
    }else{
      printf_SCHED_IO("F\r\n");
      return FALSE;
    }
  }

  async command bool TDMARoutingSchedule.isSynched[uint8_t rm](uint16_t frameNum){
    return (framesSinceLastSchedule <= curSched->activeFrames+curSched->inactiveFrames);
  }
  async command uint8_t TDMARoutingSchedule.maxRetransmit[uint8_t rm](){
//    printf_SCHED("nrs.mr\r\n");
    return curSched->maxRetransmit;
  }
  async command uint16_t TDMARoutingSchedule.framesPerSlot[uint8_t rm](){
    return curSched->framesPerSlot;
  }
  
  //unused
  event void AnnounceSend.sendDone(message_t* msg, error_t error){}
  event message_t* ReplyReceive.receive(message_t* msg, void* payload, uint8_t len){ return msg;}

  
}
