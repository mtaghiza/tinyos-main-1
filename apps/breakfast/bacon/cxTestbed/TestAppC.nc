 #include "CX.h"
 #include "schedule.h"
 #include "test.h"

configuration TestAppC{
} implementation {
  components MainC;
  components TestP;
  components SerialPrintfC;
  components PlatformSerialC;
  components LedsC;
  components new TimerMilliC() as StartupTimer;
  components new TimerMilliC() as SendTimer;
  components RandomC;

  #if STACK_PROTECTION == 1
  components StackGuardC;
  #else
  #warning Disabling stack protection
  #endif

  TestP.Boot -> MainC;
  TestP.UartStream -> PlatformSerialC;
  TestP.UartControl -> PlatformSerialC;
  TestP.Leds -> LedsC;

  TestP.StartupTimer -> StartupTimer;
  TestP.SendTimer -> SendTimer;
  TestP.Random -> RandomC;

  components CXPacketStackC;
  components CXTDMAPhysicalC;
  components CXNetworkC;
  components CXTransportC;
  components CXRoutingTableC;

  //this component is responsible for:
  // - receiving/distributing schedule-related packets
  // - instructing the phy layer how to configure itself
  // - telling the various routing methods when they are allowed to
  //   send.
  components TDMASchedulerC;
  //Scheduler: should sit above transport layer. So it should be
  //dealing with AM packets (using CX header as needed)
  TDMASchedulerC.SubSplitControl -> CXTDMAPhysicalC;
  TDMASchedulerC.AMPacket -> CXPacketStackC.AMPacket;
  TDMASchedulerC.Rf1aPacket -> CXPacketStackC.Rf1aPacket;
  TDMASchedulerC.CXPacket -> CXPacketStackC.CXPacket;
  TDMASchedulerC.CXPacketMetadata -> CXPacketStackC.CXPacketMetadata;
  TDMASchedulerC.Packet -> CXPacketStackC.CXPacketBody;
  TDMASchedulerC.CXRoutingTable -> CXRoutingTableC;

  TDMASchedulerC.TDMAPhySchedule -> CXTDMAPhysicalC;
  TDMASchedulerC.FrameStarted -> CXTDMAPhysicalC;


  TestP.SplitControl -> TDMASchedulerC.SplitControl;

  TestP.AMPacket -> CXPacketStackC.AMPacket;
  TestP.CXPacket -> CXPacketStackC.CXPacket;
  TestP.CXPacketMetadata -> CXPacketStackC.CXPacketMetadata;
  TestP.Packet -> CXPacketStackC.CXPacketBody;
  
  TestP.AMSend -> CXTransportC.SimpleFloodSend[AM_ID_CX_TESTBED];
  TestP.Receive -> CXTransportC.SimpleFloodReceive[AM_ID_CX_TESTBED];

  TestP.Rf1aPacket -> CXPacketStackC.Rf1aPacket;  
}
