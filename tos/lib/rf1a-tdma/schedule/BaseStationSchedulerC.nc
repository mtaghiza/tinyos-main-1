 #include "schedule.h"
configuration BaseStationSchedulerC {
  provides interface TDMARoutingSchedule;

  uses interface TDMAPhySchedule;
  uses interface FrameStarted;
} implementation{
  components MasterSchedulerC;
  components CXTransportC;
  
  MasterSchedulerC.FrameStarted = FrameStarted;
  MasterSchedulerC.TDMAPhySchedule = FrameStarted;

  TDMARoutingSchedule = MasterSchedulerC;
  MasterSchedulerC.AnnounceSend ->
    CXTransportC.SimpleFloodSend[AM_ID_ROUTER_SCHEDULE];
  MasterSchedulerC.RequestReceive ->
    CXTransportC.SimpleFloodReceive[AM_ID_ROUTER_REQUEST];
  MasterSchedulerC.ResponseSend -> 
    CXTransportC.SimpleFloodSend[AM_ID_ROUTER_RESPONSE];

}

