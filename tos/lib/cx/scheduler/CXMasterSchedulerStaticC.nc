/**
 *  Wiring for scheduler portion of the CX stack. Includes
 *  role-agnostic SlotScheduler (wake up/skew-correct at every slot
 *  start, sleep during slots when no activity detected) and
 *  master-specific role scheduler.
 *
 *  When started, this will periodically send out schedule
 *  announcements.
 **/
 #include "CXScheduler.h"
configuration CXMasterSchedulerStaticC{
  provides interface CXRequestQueue;
  provides interface SplitControl;
  provides interface Packet;
  provides interface SlotTiming;
} implementation {
  //CX stack components
  components CXMasterSchedulerStaticP as CXMasterSchedulerP;
  components SlotSchedulerP;
  components CXNetworkC;

  //CX Stack wiring
  SplitControl = CXMasterSchedulerP;
  CXRequestQueue = CXMasterSchedulerP;

  CXMasterSchedulerP.SubCXRQ -> SlotSchedulerP;
  CXMasterSchedulerP.SubSplitControl -> CXNetworkC;

  SlotSchedulerP.SubCXRQ -> CXNetworkC;
  
  //communication between role-specific and role-agnostic code
  CXMasterSchedulerP.SlotNotify -> SlotSchedulerP.SlotNotify;
  CXMasterSchedulerP.ScheduleParams -> SlotSchedulerP.ScheduleParams;

  //packet stack
  components CXSchedulerPacketC;
  components CXLinkPacketC;
  components CXPacketMetadataC;

  Packet = CXSchedulerPacketC;
  CXMasterSchedulerP.Packet -> CXSchedulerPacketC;
  CXMasterSchedulerP.CXSchedulerPacket -> CXSchedulerPacketC;
  CXMasterSchedulerP.CXNetworkPacket -> CXNetworkC;
  CXMasterSchedulerP.CXLinkPacket -> CXLinkPacketC;

  CXMasterSchedulerP.CXPacketMetadata -> CXPacketMetadataC;

  SlotSchedulerP.CXSchedulerPacket -> CXSchedulerPacketC;
  SlotSchedulerP.CXNetworkPacket -> CXNetworkC;

  //Skew correction 
  #if CX_ENABLE_SKEW_CORRECTION
  components SkewCorrectionC;
  #else
  #warning "Disabled skew correction."
  components DummySkewCorrectionC as SkewCorrectionC;
  #endif
  SlotSchedulerP.SkewCorrection -> SkewCorrectionC;
  CXMasterSchedulerP.SkewCorrection -> SkewCorrectionC;

  //Role scheduler internals
  components MainC;
  components RandomC;
  CXMasterSchedulerP.Boot -> MainC.Boot;
  CXMasterSchedulerP.Random -> RandomC;

  components new ScheduledAMSenderC(AM_CX_SCHEDULE_MSG) as SenderC;
  CXMasterSchedulerP.ScheduledAMSend -> SenderC;

  SlotTiming = SlotSchedulerP;

  components CXRoutingTableC;
  CXMasterSchedulerP.RoutingTable -> CXRoutingTableC;
  
  components CXAMAddressC;
  CXMasterSchedulerP.ActiveMessageAddress -> CXAMAddressC;
}
