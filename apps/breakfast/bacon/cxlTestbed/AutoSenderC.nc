
 #include "autosender.h"
 #include "multiNetwork.h"
configuration AutoSenderC{
} implementation {
  #if ENABLE_PRINTF == 1
  components SerialPrintfC;
  #endif
  components WatchDogC;
  components StackGuardMilliC;
  components AutoSenderP;

  components MainC;
  AutoSenderP.Boot -> MainC;

  components new TimerMilliC();
  AutoSenderP.Timer -> TimerMilliC;

  #if TEST_SEGMENT == NS_ROUTER_DEF
  #warning RouterAMSenderC
  components new RouterAMSenderC(AM_TEST_MSG) as AMSender;
  #elif TEST_SEGMENT == NS_SUBNETWORK_DEF
  #warning SubNetworkAMSenderC
  components new SubNetworkAMSenderC(AM_TEST_MSG) as AMSender;
  #elif TEST_SEGMENT == NS_GLOBAL_DEF
  #warning GlobalAMSenderC
  components new GlobalAMSenderC(AM_TEST_MSG) as AMSender;
  #else
  #error Must set TEST_SEGMENT to NS_xxx
  #endif
  AutoSenderP.AMSend -> AMSender;
  
  components CXLinkPacketC;
  AutoSenderP.CXLinkPacket -> CXLinkPacketC;

  components ActiveMessageC;
  AutoSenderP.Pool -> ActiveMessageC;

}
