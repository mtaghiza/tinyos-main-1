
 #include "CXMac.h"
configuration CXMacC {
  provides interface Send;
  provides interface Receive;

  provides interface SplitControl;
  uses interface Pool<message_t>;

  provides interface Packet;

} implementation {

  components CXMacP;
  components CXLppC;

  //If you need a handle to the rts/cts commands, do so *not* through
  //this component, but by directly grabbing CXBasestationMacC or
  //CXLeafMacC where you need it.
  #if CX_BASESTATION == 1
  components CXBasestationMacC as Controller;
  Controller.Pool = Pool;
  #else
  components CXLeafMacC as Controller;
  #endif

  CXMacP.CXMacController -> Controller;

  Receive = Controller.Receive;
  Controller.SubReceive -> CXLppC.Receive;
  CXLppC.Pool = Pool;
  
  SplitControl = CXLppC.SplitControl;

  Send = Controller.Send;
  Controller.SubSend -> CXMacP.Send;
  CXMacP.SubSend -> CXLppC.Send;

  Packet = CXLppC.Packet;
}
