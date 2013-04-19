/**
 *  Wiring for scheduler portion of the CX stack. Includes
 *  role-agnostic SlotScheduler (wake up/skew-correct at every slot
 *  start, sleep during slots when no activity detected) and
 *  slave-specific role scheduler.
 *
 *  When started, this will listen for schedule announcements and join
 *  the schedule.
 **/
 #include "CXScheduler.h"
configuration CXSlaveSchedulerC{
  provides interface CXRequestQueue;
  provides interface SplitControl;
  provides interface Packet; 
  #ifndef HAS_ACTIVE_MESSAGE
  //TODO: remove when AMReceive available
  uses interface Receive;
  #endif
} implementation {
  //CX stack components
  components CXSlaveSchedulerP;
  components SlotSchedulerP;
  components CXNetworkC;
  
  //CX Stack wiring
  SplitControl = CXSlaveSchedulerP;
  CXRequestQueue = CXSlaveSchedulerP;

  CXSlaveSchedulerP.SubCXRQ -> SlotSchedulerP;
  CXSlaveSchedulerP.SubSplitControl -> CXNetworkC;

  SlotSchedulerP.SubCXRQ -> CXNetworkC;
    
  //communication between role-specific and role-agnostic code
  CXSlaveSchedulerP.SlotNotify -> SlotSchedulerP.SlotNotify;
  CXSlaveSchedulerP.ScheduleParams -> SlotSchedulerP;

  //packet stack
  components CXSchedulerPacketC;
  components CXNetworkPacketC;
  components CXLinkPacketC;

  Packet = CXSchedulerPacketC;
  CXSlaveSchedulerP.Packet -> CXSchedulerPacketC;
  CXSlaveSchedulerP.CXSchedulerPacket -> CXSchedulerPacketC;
  CXSlaveSchedulerP.CXNetworkPacket -> CXNetworkPacketC;
  CXSlaveSchedulerP.CXLinkPacket -> CXLinkPacketC;

  SlotSchedulerP.CXSchedulerPacket -> CXSchedulerPacketC;
  SlotSchedulerP.CXNetworkPacket -> CXNetworkPacketC;
  
  //skew correction
  #if CX_ENABLE_SKEW_CORRECTION == 1
  components SkewCorrectionC;
  #else
  #warning "Disabled skew correction."
  components DummySkewCorrectionC as SkewCorrectionC;
  #endif
  CXSlaveSchedulerP.SkewCorrection -> SkewCorrectionC;
  SlotSchedulerP.SkewCorrection -> SkewCorrectionC;
  
  #ifdef HAS_ACTIVE_MESSAGE
  components new AMReceiverC(AM_CX_SCHEDULE_MSG);
  CXSlaveSchedulerP.ScheduleReceive -> AMReceiverC;
  #else
  //schedule reception: through normal receive path
  CXSlaveSchedulerP.ScheduleReceive = Receive;
  #endif
}
