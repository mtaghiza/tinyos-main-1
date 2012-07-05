
 #include "schedule.h"
configuration MasterSchedulerC {
  provides interface TDMARoutingSchedule;

  uses interface TDMAPhySchedule;
  uses interface FrameStarted;

  uses interface AMSend as AnnounceSend;
  uses interface Receive as RequestReceive;
  uses interface AMSend as ResponseSend;

  provides interface SplitControl;
  uses interface SplitControl as SubSplitControl;

  provides interface SlotStarted;
  provides interface ScheduledSend as ResponseSchedule;
  provides interface ScheduledSend as AnnounceSchedule;
  provides interface ScheduledSend as DefaultScheduledSend;
} implementation {
  components MasterSchedulerP;
  components CXPacketStackC;
  components ActiveMessageC;

  MasterSchedulerP.AnnounceSend = AnnounceSend; 
  MasterSchedulerP.RequestReceive = RequestReceive;
  MasterSchedulerP.ResponseSend = ResponseSend;

  MasterSchedulerP.FrameStarted = FrameStarted;
  MasterSchedulerP.TDMAPhySchedule = TDMAPhySchedule;

  MasterSchedulerP.ReceiveNotify -> ActiveMessageC.ReceiveNotify;

  TDMARoutingSchedule = MasterSchedulerP.TDMARoutingSchedule;

  SplitControl = MasterSchedulerP.SplitControl;
  MasterSchedulerP.SubSplitControl = SubSplitControl;
  MasterSchedulerP.CXPacket -> CXPacketStackC.CXPacket;
  MasterSchedulerP.PacketAcknowledgements 
    -> ActiveMessageC.PacketAcknowledgements;

  SlotStarted = MasterSchedulerP.SlotStarted;
  ResponseSchedule = MasterSchedulerP.ResponseSchedule;
  AnnounceSchedule = MasterSchedulerP.AnnounceSchedule;
  DefaultScheduledSend = MasterSchedulerP.DefaultScheduledSend;
}
