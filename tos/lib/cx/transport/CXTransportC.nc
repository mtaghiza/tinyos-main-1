configuration CXTransportC {
  provides interface SplitControl;
  provides interface Packet;

  provides interface Send as ScheduledSend;

  provides interface Send as BroadcastSend;
  provides interface Receive as BroadcastReceive;

  provides interface Send as UnicastSend;
  provides interface Receive as UnicastReceive;
} implementation {
  
  //When packets received, push them to relevant subprotocol
  components CXTransportDispatchP;
  components CXSchedulerC;

  CXTransportDispatchP.SubCXRQ -> CXSchedulerC;
  //needed so that we can notify sub-protocols when to put in their RX
  //requests
  CXTransportDispatchP.SubSplitControl -> CXSchedulerC;
  SplitControl = CXTransportDispatchP;
  
  //hook up sub-protocols
  components FloodBurstP;
  components RRBurstP;
  components ScheduledTXP;
  BroadcastSend = FloodBurstP;
  BroadcastReceive = FloodBurstP;
  UnicastSend = RRBurstP;
  UnicastReceive = RRBurstP;
  ScheduledSend = ScheduledTXP;

  ScheduledTXP.CXRequestQueue 
    -> CXTransportDispatchP.CXRequestQueue[CX_TP_SCHEDULED];
  FloodBurstP.CXRequestQueue 
    -> CXTransportDispatchP.CXRequestQueue[CX_TP_FLOOD_BURST];
  RRBurstP.CXRequestQueue 
    -> CXTransportDispatchP.CXRequestQueue[CX_TP_RR_BURST];

  FloodBurstP.SplitControl 
    -> CXTransportDispatchP.SubProtocolSplitControl[CX_TP_FLOOD_BURST];
  RRBurstP.SplitControl 
    -> CXTransportDispatchP.SubProtocolSplitControl[CX_TP_RR_BURST];

  FloodBurstP.SlotTiming -> CXSchedulerC;
  RRBurstP.SlotTiming -> CXSchedulerC;

  CXTransportDispatchP.RequestPending[CX_TP_FLOOD_BURST] 
    -> FloodBurstP.RequestPending;
  CXTransportDispatchP.RequestPending[CX_TP_RR_BURST] 
    -> RRBurstP.RequestPending;
  
  components CXTransportPacketC;
  Packet = CXTransportPacketC;

  components CXPacketMetadataC;
  ScheduledTXP.CXPacketMetadata -> CXPacketMetadataC;
  FloodBurstP.CXPacketMetadata -> CXPacketMetadataC;

  CXTransportDispatchP.CXPacketMetadata -> CXPacketMetadataC;
  CXTransportDispatchP.CXTransportPacket -> CXTransportPacketC;
  FloodBurstP.CXTransportPacket -> CXTransportPacketC;
  RRBurstP.CXTransportPacket -> CXTransportPacketC;
  FloodBurstP.Packet -> CXTransportPacketC;
  RRBurstP.Packet -> CXTransportPacketC;

  components ActiveMessageC;
  ScheduledTXP.AMPacket -> ActiveMessageC;
  ScheduledTXP.CXTransportPacket -> CXTransportPacketC;

  components CXRoutingTableC;
  FloodBurstP.RoutingTable -> CXRoutingTableC;
  FloodBurstP.AMPacket -> ActiveMessageC;

  RRBurstP.RoutingTable -> CXRoutingTableC;
  RRBurstP.AMPacket -> ActiveMessageC;

  components CXNetworkPacketC;
  RRBurstP.CXNetworkPacket -> CXNetworkPacketC;

  components new ScheduledAMSenderC(AM_CX_RR_ACK_MSG) as AckSenderC;
  RRBurstP.AckSend -> AckSenderC;
  RRBurstP.AckPacket -> AckSenderC;

  CXTransportDispatchP.AMPacket -> ActiveMessageC;

}
