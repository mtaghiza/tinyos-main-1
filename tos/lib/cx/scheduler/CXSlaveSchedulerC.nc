configuration CXSlaveSchedulerC{
  provides interface SplitControl;
  provides interface CXRequestQueue;

  provides interface Packet; 

  //TODO: remove when AMReceive available
  uses interface Receive;
} implementation {
  components CXSlaveSchedulerP;

  components SlotSchedulerP;
  components CXNetworkC;

  components CXSchedulerPacketC;
  components CXNetworkPacketC;

  SplitControl = CXSlaveSchedulerP;
  CXRequestQueue = CXSlaveSchedulerP;

  SlotSchedulerP.SubCXRQ -> CXNetworkC;
  SlotSchedulerP.SubSplitControl -> CXNetworkC;
  SlotSchedulerP.CXSchedulerPacket -> CXSchedulerPacketC;
  SlotSchedulerP.CXNetworkPacket -> CXNetworkPacketC;
  
  Packet = CXSchedulerPacketC;

  CXSlaveSchedulerP.SubCXRQ -> SlotSchedulerP;
  CXSlaveSchedulerP.SubSplitControl -> SlotSchedulerP;
  CXSlaveSchedulerP.CXNetworkPacket -> CXNetworkPacketC;
  CXSlaveSchedulerP.CXSchedulerPacket -> CXSchedulerPacketC;

  //a little backwards, but whatever
  CXSlaveSchedulerP.ScheduleParams -> SlotSchedulerP;

//TODO: wire to AM Receive when available
  CXSlaveSchedulerP.ScheduleReceive = Receive;
//  components new AMReceiverC(AM_CX_SCHEDULE);
//  CXSlaveSchedulerP.ScheduleReceive -> AMReceiverC;

  components SkewCorrectionC;
  CXSlaveSchedulerP.SkewCorrection -> SkewCorrectionC;
  SlotSchedulerP.SkewCorrection -> SkewCorrectionC;
  CXSlaveSchedulerP.SlotNotify -> SlotSchedulerP.SlotNotify;

}
