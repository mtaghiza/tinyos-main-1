configuration CXBasestationMacC{
  provides interface CXMacController;
  provides interface Receive;
  uses interface Receive as SubReceive;

  provides interface Send;
  uses interface Send as SubSend;

  provides interface CXMacMaster;
  uses interface Pool<message_t>;
} implementation {
  components CXBasestationMacP;
  CXMacController = CXBasestationMacP;
  CXMacMaster = CXBasestationMacP;

  //wire through
  Receive = CXBasestationMacP.Receive;
  CXBasestationMacP.SubReceive = SubReceive;
  
  //intercept
  Send = CXBasestationMacP;
  CXBasestationMacP.SubSend = SubSend;

  CXBasestationMacP.Pool = Pool;

  components CXLinkPacketC;
  CXBasestationMacP.CXLinkPacket -> CXLinkPacketC.CXLinkPacket;
  components CXMacPacketC;
  CXBasestationMacP.CXMacPacket -> CXMacPacketC.CXMacPacket;
  CXBasestationMacP.Packet -> CXMacPacketC.Packet;
}
