
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
  components new ScheduledAMSenderC(AM_TEST_MSG);
  components new AMSenderC(AM_TEST_MSG) as BroadcastSender;
  components new AMSenderC(AM_TEST_MSG) as UnicastSender;
  components new AMReceiverC(AM_TEST_MSG);

  TestP.BroadcastAMSend -> BroadcastSender;
  TestP.UnicastAMSend -> UnicastSender;
  TestP.ScheduledAMSend -> ScheduledAMSenderC;
  TestP.Receive -> AMReceiverC;
  TestP.SplitControl -> ActiveMessageC;
  TestP.Packet -> BroadcastSender;
  TestP.AMPacket -> ActiveMessageC;
}
