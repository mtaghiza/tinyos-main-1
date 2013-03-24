configuration CXSlaveSchedulerC{
  provides interface SplitControl;
  provides interface CXRequestQueue;

  provides interface Packet; 

  //TODO: remove when AMReceive available
  uses interface Receive;
} implementation {
  components CXSlaveSchedulerP;
  components CXNetworkC;

  components CXSchedulerPacketC;
  components CXNetworkPacketC;

  SplitControl = CXSlaveSchedulerP;
  CXRequestQueue = CXSlaveSchedulerP;

  CXSlaveSchedulerP.SubCXRQ -> CXNetworkC;
  CXSlaveSchedulerP.SubSplitControl -> CXNetworkC;
  CXSlaveSchedulerP.CXSchedulerPacket -> CXSchedulerPacketC;
  CXSlaveSchedulerP.CXNetworkPacket -> CXNetworkPacketC;
  
  Packet = CXSchedulerPacketC;

//TODO: wire to AM Receive when available
  CXSlaveSchedulerP.ScheduleReceive = Receive;
//  components new AMReceiverC(AM_CX_SCHEDULE);
//  CXSlaveSchedulerP.ScheduleReceive -> AMReceiverC;
}
