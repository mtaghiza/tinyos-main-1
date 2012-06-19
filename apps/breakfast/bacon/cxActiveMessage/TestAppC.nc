 #include "CX.h"
 #include "schedule.h"
 #include "test.h"
 #include "CXTransport.h"

configuration TestAppC{
} implementation {
  components ActiveMessageC;
  components MainC;
  components TestP;
  components SerialPrintfC;
  components PlatformSerialC;
  components LedsC;
  components new TimerMilliC() as StartupTimer;
  components new TimerMilliC() as SendTimer;
  components RandomC;

  #if STACK_PROTECTION == 1
  components StackGuardC;
  #else
  #warning Disabling stack protection
  #endif

  TestP.Boot -> MainC;
  TestP.UartStream -> PlatformSerialC;
  TestP.UartControl -> PlatformSerialC;
  TestP.Leds -> LedsC;

  TestP.StartupTimer -> StartupTimer;
  TestP.SendTimer -> SendTimer;
  TestP.Random -> RandomC;
  
  #if FLOOD_TEST == 1
  components new CXAMSenderC(AM_ID_CX_TESTBED, CX_TP_SIMPLE_FLOOD) 
    as CXAMSenderC;
  #else
  components new CXAMSenderC(AM_ID_CX_TESTBED, CX_TP_UNRELIABLE_BURST)
    as CXAMSenderC;
  #endif
  components new AMReceiverC(AM_ID_CX_TESTBED);

  TestP.AMSend -> CXAMSenderC;
  TestP.Receive -> AMReceiverC;

  TestP.Rf1aPacket -> ActiveMessageC.Rf1aPacket;  
  TestP.CXPacket -> ActiveMessageC.CXPacket;
  TestP.CXPacketMetadata -> ActiveMessageC.CXPacketMetadata;
  TestP.Packet -> ActiveMessageC.Packet;
  TestP.SplitControl -> ActiveMessageC.SplitControl;
}
