configuration CXMacC {
  provides interface Send;
  provides interface Receive;

  provides interface SplitControl;

} implementation {
  //check compile flag for whether we are base station or not
  components CXBasestationMacC as Controller;

  components CXMacP;
  CXMacP.CXMacController -> Controller;

  components CXLppC;
  Controller.SubReceive -> CXLppC.Receive;
  Receive = Controller.Receive;
  
  SplitControl = CXLppC.SplitControl;
  Send = CXMacP.Send;
}
