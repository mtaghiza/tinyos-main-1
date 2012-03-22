 #include "schedule.h"
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
  //maybe this should be done by Flood send.
  uses interface AMPacket;
} implementation {

  enum{
    S_IDLE,
    S_ANNOUNCING
  };
  uint8_t state;
  bool repliesPending;

  #if defined (TDMA_MAX_NODES) && defined (TDMA_MAX_DEPTH) && defined (TDMA_MAX_RETRANSMIT)
  #define TDMA_ROOT_FRAMES_PER_SLOT (TDMA_MAX_DEPTH + TDMA_MAX_RETRANSMIT)
  #define TDMA_ROOT_ACTIVE_FRAMES (TDMA_MAX_NODES * TDMA_ROOT_FRAMES_PER_SLOT)
  #define TDMA_ROOT_INACTIVE_FRAMES (TDMA_MAX_NODES * TDMA_ROOT_FRAMES_PER_SLOT) 
  #else
  #error Must define TDMA_MAX_NODES, TDMA_MAX_DEPTH, and TDMA_MAX_RETRANSMIT
  #endif

  uint32_t frameLen = DEFAULT_TDMA_FRAME_LEN;
  uint32_t fwCheckLen = DEFAULT_TDMA_FW_CHECK_LEN; 
  uint16_t activeFrames = TDMA_ROOT_ACTIVE_FRAMES; 
  uint16_t inactiveFrames = TDMA_ROOT_INACTIVE_FRAMES;
  uint16_t framesPerSlot = TDMA_ROOT_FRAMES_PER_SLOT;
  uint8_t maxRetransmit = TDMA_MAX_RETRANSMIT;
  uint8_t symbolRate = TDMA_INIT_SYMBOLRATE;

  message_t schedule_msg_internal;
  message_t* schedule_msg = &schedule_msg_internal;

  uint16_t framesPerSlot;
  
  command error_t SplitControl.start(){
    error_t error;
    error = call SubSplitControl.start();
    return error;
  }

  void setupPacket(message_t* msg, uint16_t originalFrame){
    cx_schedule_t* schedule_pl;
    call CXPacket.init(msg);

    call AMPacket.setDestination(msg, AM_BROADCAST_ADDR);
    call CXPacket.setDestination(msg, AM_BROADCAST_ADDR);
    schedule_pl = (cx_schedule_t*)call Packet.getPayload(msg, sizeof(cx_schedule_t));
    schedule_pl -> rootStart = 0;
    schedule_pl -> originalFrame = originalFrame;
    schedule_pl -> frameLen = frameLen;
    schedule_pl -> activeFrames = activeFrames;
    schedule_pl -> inactiveFrames = inactiveFrames;
    schedule_pl -> framesPerSlot = framesPerSlot;
    schedule_pl -> maxRetransmit = maxRetransmit;
    schedule_pl -> symbolRate = symbolRate;
  }
  task void announceSchedule();

  event void SubSplitControl.startDone(error_t error){
    if (SUCCESS == error){
      error = call TDMAPhySchedule.setNextSchedule(
        call TDMAPhySchedule.getNow(), 
        TDMA_ROOT_FRAMES_PER_SLOT*TOS_NODE_ID,
        DEFAULT_TDMA_FRAME_LEN,
        DEFAULT_TDMA_FW_CHECK_LEN, 
        TDMA_ROOT_ACTIVE_FRAMES, 
        TDMA_ROOT_INACTIVE_FRAMES, 
        TDMA_INIT_SYMBOLRATE);
      if (SUCCESS == error){
        setupPacket(schedule_msg, 
          TDMA_ROOT_FRAMES_PER_SLOT*TOS_NODE_ID);
        //state: fixin' to announce.
        //set flag to indicate that we are waiting for replies.
        post announceSchedule();
      }else{
        printf("set next schedule: %s\r\n", decodeError(error));
      }
    }
    signal SplitControl.startDone(error);
  }

  task void announceSchedule(){
    error_t error;
    error = call AnnounceSend.send(schedule_msg,
      sizeof(cx_schedule_t));
    if (SUCCESS != error){
      printf("announce schedule: %s\r\n", decodeError(error));
    }else{
      //state: announcing
    }
  }

  event void AnnounceSend.sendDone(message_t* msg, error_t error){
    if (SUCCESS != error){
      printf("send done: %s\r\n", decodeError(error));
    } else {
      //state: either idle or reply-wait (depending on flag)
    }
  }

  command error_t SplitControl.stop(){
    return call SubSplitControl.stop();
  }

  event void SubSplitControl.stopDone(error_t error){
    signal SplitControl.stopDone(error);
  }

  async event void TDMAPhySchedule.frameStarted(uint32_t startTime, 
      uint16_t frameNum){
    //TODO: record timing info for clock skew correction
  }

  async event void FrameStarted.frameStarted(uint16_t frameNum){
    //may be off-by-one
    if (frameNum == (TDMA_ROOT_FRAMES_PER_SLOT*TOS_NODE_ID)){
      post announceSchedule();
    }
  }

  async event int32_t TDMAPhySchedule.getFrameAdjustment(uint16_t frameNum){
    //as root, we let the rest of the network adjust around us.
    return 0;
  }

  async command uint16_t TDMARoutingSchedule.framesPerSlot[uint8_t rm](){
    return framesPerSlot;
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
    return maxRetransmit;
  }

  event message_t* ReplyReceive.receive(message_t* msg, void* payload,
      uint8_t len){
    //TODO: logic for making sure we didnt' disconnect the network,
    //counting up max depth, etc.
    return msg;
  }

  //unused
  event void ReplySend.sendDone(message_t* msg, error_t error){}
  event message_t* AnnounceReceive.receive(message_t* msg, 
      void* payload, uint8_t len){
    return msg; 
  }
}
