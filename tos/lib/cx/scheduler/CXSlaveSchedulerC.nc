configuration CXSlaveSchedulerC{
  provides interface SplitControl;
  provides interface CXRequestQueue;
  
  //TODO: remove when AMReceive available
  uses interface Receive;
} implementation {
  components CXSlaveSchedulerP;
  components CXNetworkC;

  components CXSchedulerPacketC;

  SplitControl = CXSlaveSchedulerP;
  CXRequestQueue = CXSlaveSchedulerP;

  CXSlaveSchedulerP.SubCXRQ -> CXNetworkC;
  CXSlaveSchedulerP.SubSplitControl -> CXNetworkC;
  CXSlaveSchedulerP.CXSchedulerPacket -> CXSchedulerPacketC;
  CXSlaveSchedulerP.CXPacketMetadata -> CXSchedulerPacketC;


//TODO: wire to AM Receive when available
  CXSlaveSchedulerP.ScheduleReceive = Receive;
//  components new AMReceiverC(AM_CX_SCHEDULE);
//  CXSlaveSchedulerP.ScheduleReceive -> AMReceiverC;
}
