
 #include "test.h"
configuration TestAppC {
} implementation {
  components PlatformSerialC;
  components SerialPrintfC;

  components ActiveMessageC;

  components TestP;
  components LedsC;

  TestP.SplitControl -> ActiveMessageC;

  components new AMSenderC(AM_TEST_PAYLOAD);
  components new AMReceiverC(AM_TEST_PAYLOAD);
  TestP.Receive -> AMReceiverC;
  TestP.AMSend -> AMSenderC;

  TestP.Leds -> LedsC;

  components MainC;
  TestP.Boot -> MainC;

  TestP.UartStream -> PlatformSerialC;
  TestP.SerialControl -> PlatformSerialC;
  TestP.Packet -> AMSenderC;

  TestP.Pool -> ActiveMessageC.Pool;
  components PingC;
  PingC.Pool -> ActiveMessageC.Pool;

  #if CX_ROUTER == 1
  components CXRouterC;
  TestP.CXDownload -> CXRouterC.CXDownload;
  #endif
}
