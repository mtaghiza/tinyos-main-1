/*
 * Copyright (c) 2014 Johns Hopkins University.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#include "schedule.h"
#include "CXTransport.h"

configuration RouterSchedulerC {
  provides interface TDMARoutingSchedule;

  uses interface TDMAPhySchedule;
  uses interface FrameStarted;
  provides interface SplitControl;
  uses interface SplitControl as SubSplitControl;
  provides interface SlotStarted;
  provides interface ScheduledSend as DefaultScheduledSend;
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
  components ActiveMessageC;
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
  
  components new AMSenderC(AM_ID_LEAF_SCHEDULE)
    as MasterAnnounceSend;
  components new AMReceiverC(AM_ID_LEAF_REQUEST) as MasterRequestReceive;
  components new AMSenderC(AM_ID_LEAF_RESPONSE)
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
  components new AMSenderC(AM_ID_ROUTER_REQUEST) 
    as SlaveRequestSend;
  components new AMReceiverC(AM_ID_ROUTER_RESPONSE) 
    as SlaveResponseReceive;
  SlaveSchedulerC.AnnounceReceive -> SlaveAnnounceReceive;
  SlaveSchedulerC.RequestSend -> SlaveRequestSend;
  SlaveSchedulerC.ResponseReceive -> SlaveResponseReceive;
  
  DefaultScheduledSend = RouterSchedulerP.DefaultScheduledSend;
  RouterSchedulerP.SubDefaultScheduledSend[CX_SCHEDULER_SLAVE] 
    -> SlaveSchedulerC.DefaultScheduledSend;
  RouterSchedulerP.SubDefaultScheduledSend[CX_SCHEDULER_MASTER] 
    -> MasterSchedulerC.DefaultScheduledSend;
}

