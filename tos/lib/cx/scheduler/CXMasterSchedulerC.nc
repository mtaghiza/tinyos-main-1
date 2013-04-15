configuration CXMasterSchedulerC{
  provides interface SplitControl;
  provides interface CXRequestQueue;

  provides interface Packet;

} implementation {
  components CXMasterSchedulerP;
  components SlotSchedulerP;
  components CXNetworkC;
  components SkewCorrectionC;

  components MainC;
  CXMasterSchedulerP.Boot -> MainC.Boot;
  components RandomC;
  CXMasterSchedulerP.Random -> RandomC;

  SplitControl = CXMasterSchedulerP;
  CXRequestQueue = CXMasterSchedulerP;


  SlotSchedulerP.SubCXRQ -> CXNetworkC;
  SlotSchedulerP.SubSplitControl -> CXNetworkC;
  SlotSchedulerP.CXSchedulerPacket -> CXSchedulerPacketC;
  SlotSchedulerP.CXNetworkPacket -> CXNetworkC;

  SlotSchedulerP.SkewCorrection -> SkewCorrectionC;

  CXMasterSchedulerP.SubCXRQ -> SlotSchedulerP;
  CXMasterSchedulerP.SubSplitControl -> SlotSchedulerP;
  CXMasterSchedulerP.SlotNotify -> SlotSchedulerP.SlotNotify;
  CXMasterSchedulerP.ScheduleParams -> SlotSchedulerP.ScheduleParams;

  components CXSchedulerPacketC;
  CXMasterSchedulerP.CXSchedulerPacket -> CXSchedulerPacketC;
  CXMasterSchedulerP.Packet -> CXSchedulerPacketC;
  Packet = CXSchedulerPacketC;

   
  //for addr
  components CXLinkPacketC;
  CXMasterSchedulerP.CXLinkPacket -> CXLinkPacketC;
  CXMasterSchedulerP.CXNetworkPacket -> CXNetworkC;

}
