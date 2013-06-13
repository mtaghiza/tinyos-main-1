configuration CXLeafMacC {
  provides interface CXMacController;
  provides interface Receive;
  uses interface Receive as SubReceive;
} implementation {
  components CXLeafMacP;
  CXLeafMacP.SubReceive = SubReceive;
  Receive = CXLeafMacP.Receive;
  CXMacController = CXLeafMacP.CXMacController;
}
