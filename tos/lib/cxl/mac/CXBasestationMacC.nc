configuration CXBasestationMacC{
  provides interface CXMacController;
  provides interface Receive;
  uses interface Receive as SubReceive;
} implementation {
  components CXBasestationMacP;
  CXMacController = CXBasestationMacP;

  //wire through
  Receive = SubReceive;
}
