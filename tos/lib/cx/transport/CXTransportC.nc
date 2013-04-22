configuration CXTransportC {
  provides interface SplitControl;
  provides interface Packet;

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
  BroadcastSend = FloodBurstP;
  BroadcastReceive = FloodBurstP;
  UnicastSend = RRBurstP;
  UnicastReceive = RRBurstP;


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

}
