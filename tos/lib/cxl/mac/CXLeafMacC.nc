configuration CXLeafMacC {
  provides interface CXMacController;
  provides interface Receive;
  uses interface Receive as SubReceive;
  provides interface Send;
  uses interface Send as SubSend;
} implementation {
  components CXLeafMacP;
  CXLeafMacP.SubReceive = SubReceive;
  Receive = CXLeafMacP.Receive;
  CXMacController = CXLeafMacP.CXMacController;
  
  //non-intercepted
  Send = CXLeafMacP.Send;
  CXLeafMacP.SubSend = SubSend;

  components CXLinkPacketC;
  components CXMacPacketC;
  CXLeafMacP.CXLinkPacket -> CXLinkPacketC;
  CXLeafMacP.CXMacPacket -> CXMacPacketC;
}
