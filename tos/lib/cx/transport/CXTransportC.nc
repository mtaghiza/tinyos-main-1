configuration CXTransportC {
  provides interface Send;
  provides interface Receive;
  provides interface SplitControl;
  provides interface Packet;
} implementation {
  //responsible for distributing TX to relevant sub-protocol, 
  //  merging RX from sub-protocols
  components CXTransportShimP;
  Send = CXTransportShimP;
  Receive = CXTransportShimP;
  
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
  CXTransportShimP.BroadcastSend -> FloodBurstP;
  CXTransportShimP.BroadcastReceive -> FloodBurstP;
  CXTransportShimP.UnicastSend -> RRBurstP;
  CXTransportShimP.UnicastReceive -> RRBurstP;

  FloodBurstP.CXRequestQueue 
    -> CXTransportDispatchP.CXRequestQueue[CX_TP_FLOOD_BURST];
  RRBurstP.CXRequestQueue 
    -> CXTransportDispatchP.CXRequestQueue[CX_TP_RR_BURST];
  FloodBurstP.SplitControl 
    -> CXTransportDispatchP.SubProtocolSplitControl[CX_TP_FLOOD_BURST];
  RRBurstP.SplitControl 
    -> CXTransportDispatchP.SubProtocolSplitControl[CX_TP_RR_BURST];
  
  components CXTransportPacketC;
  Packet = CXTransportPacketC;

  CXTransportDispatchP.CXTransportPacket -> CXTransportPacketC;
  FloodBurstP.CXTransportPacket -> CXTransportPacketC;
  RRBurstP.CXTransportPacket -> CXTransportPacketC;
  FloodBurstP.Packet -> CXTransportPacketC;
  RRBurstP.Packet -> CXTransportPacketC;

  components ActiveMessageC;
  CXTransportShimP.Packet -> CXTransportPacketC;
  CXTransportShimP.AMPacket -> ActiveMessageC;

}
