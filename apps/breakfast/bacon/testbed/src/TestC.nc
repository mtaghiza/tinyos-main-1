
 #include "test.h"
configuration TestC {
} implementation {
  components MainC;
  #if SCHEDULED_TEST == 1
  #warning Using scheduled test
  components ScheduledTestP as TestP;
  #else
  #warning Using random test
  components RandomTestP as TestP;
  #endif
  
  components StackGuardMilliC;
  components PlatformSerialC;
  components SerialPrintfC;

  TestP.Boot -> MainC;
  TestP.UartStream -> PlatformSerialC;
  
  components ActiveMessageC;
  components new AMSenderC(AM_TEST_MSG);
  components new AMReceiverC(AM_TEST_MSG);

  components SkewCorrectionC;

  TestP.AMSend -> AMSenderC;
  TestP.Receive -> AMReceiverC;
  TestP.SplitControl -> ActiveMessageC;
  TestP.Packet -> AMSenderC;
  TestP.AMPacket -> ActiveMessageC;
  TestP.SkewCorrection -> SkewCorrectionC;

  components CXAMAddressC;
  TestP.ActiveMessageAddress -> CXAMAddressC;

  components RandomC;
  TestP.Random ->RandomC;

  components new TimerMilliC();
  TestP.Timer -> TimerMilliC;
}
