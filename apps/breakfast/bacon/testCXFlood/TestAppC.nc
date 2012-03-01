#include "testCXFlood.h"

configuration TestAppC{
} implementation {
  components MainC;
  components TestP;
  components new TimerMilliC();
  components SerialPrintfC;
  components PlatformSerialC;

  TestP.Boot -> MainC;
  TestP.Timer -> TimerMilliC;
  TestP.UartStream -> PlatformSerialC;
  TestP.UartControl -> PlatformSerialC;

  components new AMSenderC(CX_ID_TEST);
  components new AMReceiverC(CX_ID_TEST);
  components ActiveMessageC;
  components Rf1aActiveMessageC;
  TestP.AMSend -> AMSenderC;
  TestP.Receive -> AMReceiverC;
  TestP.SplitControl -> ActiveMessageC;
  TestP.CXFloodControl -> Rf1aActiveMessageC;


  components GlossyRf1aSettings125KC as Rf1aSettings;
  Rf1aActiveMessageC.Rf1aConfigure -> Rf1aSettings;
  TestP.Rf1aPhysical -> Rf1aActiveMessageC;
  TestP.HplMsp430Rf1aIf -> Rf1aActiveMessageC;
}
