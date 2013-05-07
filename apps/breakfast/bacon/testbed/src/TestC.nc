
 #include "test.h"
configuration TestC {
} implementation {
  components MainC, TestP;
  
  components StackGuardMilliC;
  components PlatformSerialC;
  components SerialPrintfC;

  TestP.Boot -> MainC;
  TestP.UartStream -> PlatformSerialC;
  
  components ActiveMessageC;
  components new AMSenderC(AM_TEST_MSG);
  components new AMReceiverC(AM_TEST_MSG);

  TestP.AMSend -> AMSenderC;
  TestP.Receive -> AMReceiverC;
  TestP.SplitControl -> ActiveMessageC;
  TestP.Packet -> AMSenderC;
  TestP.AMPacket -> ActiveMessageC;

  components CXAMAddressC;
  TestP.ActiveMessageAddress -> CXAMAddressC;

  components RandomC;
  TestP.Random ->RandomC;

  components new TimerMilliC();
  TestP.Timer -> TimerMilliC;
}
