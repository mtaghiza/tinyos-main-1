 #include "CX.h"
 #include "schedule.h"

configuration TestAppC{
} implementation {
  components MainC;
  components TestP;
  components SerialPrintfC;
  components PlatformSerialC;
  components LedsC;
  components new TimerMilliC();

  TestP.Boot -> MainC;
  TestP.UartStream -> PlatformSerialC;
  TestP.UartControl -> PlatformSerialC;
  TestP.Leds -> LedsC;

  TestP.Timer -> TimerMilliC;

  

  components new Rf1aPhysicalC();

  components new Rf1aIeee154PacketC() as Ieee154Packet; 
  Ieee154Packet.Rf1aPhysicalMetadata -> Rf1aPhysicalC;
  components Ieee154AMAddressC;

  components Rf1aCXPacketC;
  Rf1aCXPacketC.SubPacket -> Ieee154Packet;
  Rf1aCXPacketC.Ieee154Packet -> Ieee154Packet;
  Rf1aCXPacketC.Rf1aPacket -> Ieee154Packet;

  components Rf1aAMPacketC as AMPacket;
  AMPacket.SubPacket -> Rf1aCXPacketC;
  AMPacket.Ieee154Packet -> Ieee154Packet;
  AMPacket.Rf1aPacket -> Ieee154Packet;
  AMPacket.ActiveMessageAddress -> Ieee154AMAddressC;
  Rf1aCXPacketC.AMPacket -> AMPacket;

  components CXTDMAPhysicalC;
  CXTDMAPhysicalC.HplMsp430Rf1aIf -> Rf1aPhysicalC;
  CXTDMAPhysicalC.Resource -> Rf1aPhysicalC;
  CXTDMAPhysicalC.Rf1aPhysical -> Rf1aPhysicalC;
  CXTDMAPhysicalC.Rf1aPhysicalMetadata -> Rf1aPhysicalC;
  CXTDMAPhysicalC.Rf1aStatus -> Rf1aPhysicalC;
  CXTDMAPhysicalC.Rf1aPacket -> Ieee154Packet;
  CXTDMAPhysicalC.CXPacket -> Rf1aCXPacketC;
  CXTDMAPhysicalC.CXPacketMetadata -> Rf1aCXPacketC;
  
  components SRFS7_915_GFSK_1P2K_SENS_HC;
  components SRFS7_915_GFSK_4P8K_SENS_HC;
  components SRFS7_915_GFSK_50K_SENS_HC;
  components SRFS7_915_GFSK_100K_SENS_HC;
  components SRFS7_915_GFSK_125K_SENS_HC;
  components SRFS7_915_GFSK_175K_SENS_HC;
  components SRFS7_915_GFSK_250K_SENS_HC;

  CXTDMAPhysicalC.SubRf1aConfigure[1]   -> SRFS7_915_GFSK_1P2K_SENS_HC;
  CXTDMAPhysicalC.SubRf1aConfigure[5]   -> SRFS7_915_GFSK_4P8K_SENS_HC;
  CXTDMAPhysicalC.SubRf1aConfigure[50]  -> SRFS7_915_GFSK_50K_SENS_HC;
  CXTDMAPhysicalC.SubRf1aConfigure[100] -> SRFS7_915_GFSK_100K_SENS_HC;
  CXTDMAPhysicalC.SubRf1aConfigure[125] -> SRFS7_915_GFSK_125K_SENS_HC;
  CXTDMAPhysicalC.SubRf1aConfigure[175] -> SRFS7_915_GFSK_175K_SENS_HC;
  CXTDMAPhysicalC.SubRf1aConfigure[250] -> SRFS7_915_GFSK_250K_SENS_HC;

  Rf1aPhysicalC.Rf1aConfigure -> CXTDMAPhysicalC.Rf1aConfigure;

  components new QueueC(message_t*, CX_MESSAGE_POOL_SIZE)
    as FloodQueue;
  components new QueueC(message_t*, CX_MESSAGE_POOL_SIZE)
    as ScopedFloodQueue;
  components new PoolC(message_t, CX_MESSAGE_POOL_SIZE);

  components CXTDMADispatchC;
  CXTDMADispatchC.SubCXTDMA -> CXTDMAPhysicalC;
  CXTDMADispatchC.CXPacket -> Rf1aCXPacketC;
  CXTDMADispatchC.CXPacketMetadata -> Rf1aCXPacketC;

  //this is just used to keep the enumerated arbiter happy
  enum{
    CX_RM_FLOOD_UC = unique(CXTDMA_RM_RESOURCE),
  };

  components CXFloodC;
  CXFloodC.CXTDMA -> CXTDMADispatchC.CXTDMA[CX_RM_FLOOD];
  CXFloodC.Resource -> CXTDMADispatchC.Resource[CX_RM_FLOOD];
  CXFloodC.CXPacket -> Rf1aCXPacketC;
  CXFloodC.AMPacket -> AMPacket;
  CXFloodC.LayerPacket -> Rf1aCXPacketC;
  CXFloodC.Pool -> PoolC;
  CXFloodC.Queue -> FloodQueue;

  //this is just used to keep the enumerated arbiter happy
  enum{
    CX_RM_SCOPEDFLOOD_UC = unique(CXTDMA_RM_RESOURCE),
  };

  components CXScopedFloodC;
  CXScopedFloodC.CXTDMA -> CXTDMADispatchC.CXTDMA[CX_RM_SCOPEDFLOOD];
  CXScopedFloodC.Resource -> CXTDMADispatchC.Resource[CX_RM_SCOPEDFLOOD];
  CXScopedFloodC.CXPacket -> Rf1aCXPacketC;
  CXScopedFloodC.LayerPacket -> Rf1aCXPacketC;
  CXScopedFloodC.AMPacket -> AMPacket;
  CXFloodC.Pool -> PoolC;
  CXFloodC.Queue -> ScopedFloodQueue;

  components CXRoutingTableC;
  CXScopedFloodC.CXRoutingTable -> CXRoutingTableC;

  CXFloodC.CXRoutingTable -> CXRoutingTableC;


  //this component is responsible for:
  // - receiving/distributing schedule-related packets
  // - instructing the phy layer how to configure itself
  // - telling the various routing methods when they are allowed to
  //   send.
  components TDMASchedulerC;
  TDMASchedulerC.SubSplitControl -> CXTDMAPhysicalC;
  TDMASchedulerC.FloodSend -> CXFloodC.Send;
  TDMASchedulerC.FloodReceive -> CXFloodC.Receive;
  TDMASchedulerC.ScopedFloodSend -> CXScopedFloodC.Send;
  TDMASchedulerC.ScopedFloodReceive -> CXScopedFloodC.Receive;
  TDMASchedulerC.AMPacket -> AMPacket;
  TDMASchedulerC.Rf1aPacket -> Ieee154Packet;
  TDMASchedulerC.CXPacket -> Rf1aCXPacketC;
  TDMASchedulerC.CXPacketMetadata -> Rf1aCXPacketC;
  TDMASchedulerC.Packet -> Rf1aCXPacketC;
  TDMASchedulerC.CXRoutingTable -> CXRoutingTableC;

  TDMASchedulerC.TDMAPhySchedule -> CXTDMAPhysicalC;
  TDMASchedulerC.FrameStarted -> CXTDMAPhysicalC;

  CXFloodC.TDMARoutingSchedule -> TDMASchedulerC.TDMARoutingSchedule[CX_RM_FLOOD];
  CXScopedFloodC.TDMARoutingSchedule -> TDMASchedulerC.TDMARoutingSchedule[CX_RM_SCOPEDFLOOD];
  

  TestP.SplitControl -> TDMASchedulerC.SplitControl;

  TestP.AMPacket -> AMPacket;
  TestP.CXPacket -> Rf1aCXPacketC;
  TestP.CXPacketMetadata -> Rf1aCXPacketC;
  TestP.Packet -> Rf1aCXPacketC;

  TestP.Send -> TDMASchedulerC.Send;
  TestP.Receive -> TDMASchedulerC.Receive;
  TestP.Rf1aPacket -> Ieee154Packet;  
}
