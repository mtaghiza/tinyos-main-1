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
  message_t sched_1;
  message_t sched_2;
  message_t* curMsg = &sched_1;
  message_t* nextMsg = &sched_2;
  cx_schedule_t* curSched;

  message_t reply_msg_internal;
  message_t* replyMsg = &reply_msg_internal;

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

  #define DELTA_BUF_LEN 8
  int32_t delta[DELTA_BUF_LEN];

  command error_t SplitControl.start(){
    return call SubSplitControl.start();
  }

  //initialize curSched to try to catch a new schedule announcement.
  event void SubSplitControl.startDone(error_t error){
    curSched = (cx_schedule_t*)(call Packet.getPayload(curMsg, sizeof(cx_schedule_t)));
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
    }
  }

  event message_t* AnnounceReceive.receive(message_t* msg, 
      void* payload, uint8_t len){
    cx_schedule_t* pl = (cx_schedule_t*) payload;
    uint32_t rxTS;
    uint16_t rxFrameNum;
    //update clock skew figures 
    //This isn't quite right: we are still assuming that we get this
    //event during the frame in which we first receive it (sub layers
    //may buffer it, though)
    //maybe we should add some metadata for receivedAt? or
    //something? dang it.
    rxFrameNum = call CXPacketMetadata.getFrameNum(msg);  
    rxTS = call CXPacketMetadata.getReceivedAt(msg);
    //TODO: this should only be done if the schedule is the same for
    //both this cycle and the last.
    if(lastRxTS != 0){
      uint32_t rootTicks;
      uint32_t myTicks;
      int32_t d;
      int32_t framesElapsed = 
        curSched->activeFrames+curSched->inactiveFrames;
      rootTicks = call CXPacket.getTimestamp(msg) - lastRootStart;
      myTicks = rxTS - lastRxTS;
      d = myTicks - rootTicks;
      delta[cycleNum++] = d;
      //TODO: double check this logic. 
      if ( d > framesElapsed ){
        //evenly distribute as much as possible
        ticksPerFrame = d/framesElapsed;
        //distribute leftovers over the rest of the frames as evenly
        //as possible. 
        d -= (ticksPerFrame*framesElapsed);
        extraFrames = framesElapsed/d;
        //TODO: div/0
        extraFrameOffset = 1;
        //If frameNum %extraFrames != 0, add another tick to the last
        //frame.
        endOfCycle = (framesElapsed % extraFrames)?1:0;
      }else if ( d < -1*framesElapsed){
        //same but for negative ticks
        ticksPerFrame = -1* (d/framesElapsed);
        d -= (ticksPerFrame*framesElapsed);
        extraFrames = -1*(framesElapsed/d);
        extraFrameOffset = -1;
        endOfCycle = (framesElapsed % extraFrames)?-1:0;
      }
    }

    lastRxTS = rxTS;
    lastRxFrameNum = rxFrameNum;
    lastRootStart = call CXPacket.getTimestamp(msg);
    if (pl->scheduleNum != curSched->scheduleNum){
      message_t* swp = nextMsg;
      changePending = TRUE;
      nextMsg = msg;
      return swp;
    }
    return msg; 
  }

  task void replyTask(){
    error_t error;
    cx_schedule_reply_t* reply = 
      (cx_schedule_reply_t*)call ReplySend.getPayload(replyMsg, sizeof(cx_schedule_reply_t));
    reply->scheduleNum = curSched->scheduleNum;
    error = call ReplySend.send(replyMsg, sizeof(replyMsg));
    if (SUCCESS == error){
      changePending = FALSE;
      replyPending = TRUE;
    }else{
      printf("ReplySend: %s\r\n", decodeError(error));
    }
  }

  async event void FrameStarted.frameStarted(uint16_t frameNum){
    //may be off by one
    if (changePending && (frameNum ==
        (curSched->activeFrames+curSched->inactiveFrames))){
      error_t error;
      message_t* swp = curMsg;
      curMsg = nextMsg;
      nextMsg = swp;
      curSched = (cx_schedule_t*) call Packet.getPayload(curMsg,
       sizeof(cx_schedule_t));
      error = call TDMAPhySchedule.setSchedule(lastRxTS, 
        lastRxFrameNum,
        curSched->frameLen,
        curSched->fwCheckLen, 
        curSched->activeFrames,
        curSched->inactiveFrames, 
        curSched->symbolRate);
      if (SUCCESS == error){
        post replyTask();
      }else{
        printf("setSchedule: %s\r\n", decodeError(error));
      }
    }
  }

  event void ReplySend.sendDone(message_t* msg, error_t error){
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
    //TODO: div/0
    return ticksPerFrame 
      + ((frameNum %extraFrames == 0)?extraFrameOffset:0)
      + ((frameNum == 
          (curSched->activeFrames + curSched->inactiveFrames -1))
          ? endOfCycle
          : 0);
  }

  //we are origin if reply needed and this is the start of our slot.
  async command bool TDMARoutingSchedule.isOrigin[uint8_t rm](uint16_t frameNum){
    if ((rm == CX_RM_FLOOD) 
        && replyPending 
        && (frameNum == (TOS_NODE_ID * (curSched->framesPerSlot)))){
      return TRUE;
    }else{
      return FALSE;
    }
  }

  async command bool TDMARoutingSchedule.isSynched[uint8_t rm](uint16_t frameNum){
    //TODO: TRUE iff we got the last schedule packet.
    return TRUE;
  }
  async command uint8_t TDMARoutingSchedule.maxRetransmit[uint8_t rm](){
    return curSched->maxRetransmit;
  }
  async command uint16_t TDMARoutingSchedule.framesPerSlot[uint8_t rm](){
    return curSched->framesPerSlot;
  }
  
  //unused
  event void AnnounceSend.sendDone(message_t* msg, error_t error){}
  event message_t* ReplyReceive.receive(message_t* msg, void* payload, uint8_t len){ return msg;}

  
}
