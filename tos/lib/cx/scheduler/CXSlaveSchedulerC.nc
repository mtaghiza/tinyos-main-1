/**
 *  Wiring for scheduler portion of the CX stack. Includes
 *  role-agnostic SlotScheduler (wake up/skew-correct at every slot
 *  start, sleep during slots when no activity detected) and
 *  slave-specific role scheduler.
 *
 *  When started, this will listen for schedule announcements and join
 *  the schedule.
 **/
configuration CXSlaveSchedulerC{
  provides interface CXRequestQueue;
  provides interface SplitControl;
  provides interface Packet; 
  //TODO: remove when AMReceive available
  uses interface Receive;
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
  components SkewCorrectionC;
  CXSlaveSchedulerP.SkewCorrection -> SkewCorrectionC;
  SlotSchedulerP.SkewCorrection -> SkewCorrectionC;
  
  //schedule reception: through normal receive path
//TODO: wire to AM Receive when available
  CXSlaveSchedulerP.ScheduleReceive = Receive;
//  components new AMReceiverC(AM_CX_SCHEDULE);
//  CXSlaveSchedulerP.ScheduleReceive -> AMReceiverC;
}
