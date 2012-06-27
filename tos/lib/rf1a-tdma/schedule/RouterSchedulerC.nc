#include "schedule.h"
#include "CXTransport.h"

configuration RouterSchedulerC {
  provides interface TDMARoutingSchedule;

  uses interface TDMAPhySchedule;
  uses interface FrameStarted;
  provides interface SplitControl;
  uses interface SplitControl as SubSplitControl;
  provides interface SlotStarted;

} implementation {

  /**
   * All right, this is is a little convoluted, but hear me out.
   * 
   * RouterSchedulerC is meant to be a black box: the user application
   * turns on the entire radio stack with SplitControl.start, the
   * elements at the transport/network layers use its TDMARoutingSchedule
   * interface, and it uses the TDMAPhySchedule interface of the
   * link layer. 
   *
   * This should look the same as the pure-slave scheduler (for leaf nodes)
   * and the pure-master scheduler (for the base station) externally. 
   * 
   * The RouterSchedulerP wraps the slave and master schedulers. 
   * It dispatches from the lower layers
   * (SubSplitControl, FrameStarted, and TDMAPhySchedule) to the
   * sub-schedulers. It also dispatches from the sub-schedulers to the
   * higher layers (SplitControl, TDMARoutingSchedule). 
   *
   * So, for instance, when a user application calls
   * SplitControl.start, RouterSchedulerP figures out which
   * sub-scheduler should get that command. When one of the
   * sub-schedulers calls SubSplitControl.start, that goes through
   * RouterSchedulerP again and down to the bottom of the stack. The
   * reason for these shenangans is that depending on the point in the
   * overall TDMA cycle, we want one scheduler or the other to get
   * FrameStarted events, answer questions about whether a packet
   * should be sent, indicate the channel to use, etc.  
   * 
   * The goal of RouterSchedulerP is to watch the FrameStarted events
   * and figure out which sub-scheduler should be the one that's
   * currently active.
   * 
   * We also make sure that the AMSend/Receives used by the
   * sub-schedulers are consistent with the role in the network (e.g.
   * routers are slaves on the AM_ID_ROUTER_XXX ports).
   *
   */
  /***
    Maybe this will help clear things up.

       / AppSplitControl
       |
   +---|---------------------+
   |   |   RouterSchedulerC  |
   | +-*----------------+    |
   | | RouterSchedulerP |    |
   | +--*--*---+        |    |
   |   /    \  |        |    | <- MetaSplitControl
   |  [m]  [s] |        |    | <- master/slave configs
   |   \    /  |        |    | <- MetaSubSplitControl
   | +--*--*---+        |    |
   | |                  |    |
   | +-*----------------+    |
   |   |                     |
   +---|---------------------+
       |
       \ SubSplitControl
  */

  //FrameStarted triggers all the state transitions in 
  //the sub-components, so with a little care we should be able to
  //make them independent of each other.
  components MasterSchedulerC;
  components SlaveSchedulerC;
  
  //TODO: should be SimpleFloodSenderC()'s, not direct wiring 
  components CXTransportC;
  
  //The RouterSchedulerP deals with dispatching events based on the
  //currently-active scheduler.
  components RouterSchedulerP;

  SlotStarted = RouterSchedulerP.SlotStarted;
  RouterSchedulerP.SubSlotStarted[CX_SCHEDULER_MASTER] 
    -> MasterSchedulerC;
  RouterSchedulerP.SubSlotStarted[CX_SCHEDULER_SLAVE] 
    -> SlaveSchedulerC;

  TDMAPhySchedule = RouterSchedulerP.SubTDMAPhySchedule;
  SlaveSchedulerC.TDMAPhySchedule
    -> RouterSchedulerP.TDMAPhySchedule[CX_SCHEDULER_SLAVE] ;
  MasterSchedulerC.TDMAPhySchedule
    -> RouterSchedulerP.TDMAPhySchedule[CX_SCHEDULER_MASTER] ;

  TDMARoutingSchedule = RouterSchedulerP.TDMARoutingSchedule;
  RouterSchedulerP.SubTDMARoutingSchedule[CX_SCHEDULER_SLAVE] 
    -> SlaveSchedulerC.TDMARoutingSchedule;
  RouterSchedulerP.SubTDMARoutingSchedule[CX_SCHEDULER_MASTER] 
    -> MasterSchedulerC.TDMARoutingSchedule;

  SplitControl = RouterSchedulerP.AppSplitControl;
  RouterSchedulerP.SubSplitControl = SubSplitControl;
  SlaveSchedulerC.SubSplitControl ->
    RouterSchedulerP.MetaSubSplitControl[CX_SCHEDULER_SLAVE];
  MasterSchedulerC.SubSplitControl ->
    RouterSchedulerP.MetaSubSplitControl[CX_SCHEDULER_MASTER];
  RouterSchedulerP.MetaSplitControl[CX_SCHEDULER_SLAVE] 
    -> SlaveSchedulerC.SplitControl;
  RouterSchedulerP.MetaSplitControl[CX_SCHEDULER_MASTER] 
    -> MasterSchedulerC.SplitControl;

  RouterSchedulerP.SubFrameStarted = FrameStarted;
  SlaveSchedulerC.FrameStarted ->
    RouterSchedulerP.FrameStarted[CX_SCHEDULER_SLAVE];
  MasterSchedulerC.FrameStarted ->
    RouterSchedulerP.FrameStarted[CX_SCHEDULER_MASTER];
  
  components new CXAMSenderC(AM_ID_LEAF_SCHEDULE, CX_TP_SIMPLE_FLOOD)
    as MasterAnnounceSend;
  components new AMReceiverC(AM_ID_LEAF_REQUEST) as MasterRequestReceive;
  components new CXAMSenderC(AM_ID_LEAF_RESPONSE, CX_TP_SIMPLE_FLOOD)
    as MasterResponseSend;

  MasterSchedulerC.AnnounceSend -> MasterAnnounceSend;
  MasterAnnounceSend.ScheduledSend 
    -> MasterSchedulerC.AnnounceSchedule;
  MasterSchedulerC.RequestReceive -> MasterRequestReceive;
  MasterSchedulerC.ResponseSend -> MasterResponseSend;
  MasterResponseSend.ScheduledSend 
    -> MasterSchedulerC.ResponseSchedule;

  components new AMReceiverC(AM_ID_ROUTER_SCHEDULE) 
    as SlaveAnnounceReceive;
  components new CXAMSenderC(AM_ID_ROUTER_REQUEST, CX_TP_SIMPLE_FLOOD) 
    as SlaveRequestSend;
  components new AMReceiverC(AM_ID_ROUTER_RESPONSE) 
    as SlaveResponseReceive;
  SlaveSchedulerC.AnnounceReceive -> SlaveAnnounceReceive;
  SlaveSchedulerC.RequestSend -> SlaveRequestSend;
  SlaveSchedulerC.ResponseReceive -> SlaveResponseReceive;

}

