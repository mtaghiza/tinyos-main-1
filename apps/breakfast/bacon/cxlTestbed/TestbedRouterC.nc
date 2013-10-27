
 #include "testbed.h"
 #include "autosender.h"
configuration TestbedRouterC{
} implementation {
  components TestbedRouterP;
  components CXRouterC;
  components SlotSchedulerC;
  components new RouterAMSenderC(AM_TEST_MSG) as AMSenderC;
  components new AMReceiverC(AM_TEST_MSG);

  TestbedRouterP.CXDownload -> CXRouterC.CXDownload[NS_SUBNETWORK];
  TestbedRouterP.DownloadNotify -> SlotSchedulerC.DownloadNotify[NS_ROUTER];
  TestbedRouterP.Receive -> AMReceiverC;
  TestbedRouterP.AMSend -> AMSenderC;

  components ActiveMessageC;
  components CXLinkPacketC;
  TestbedRouterP.Pool -> ActiveMessageC;
  TestbedRouterP.CXLinkPacket -> CXLinkPacketC;
  TestbedRouterP.Packet -> AMSenderC;
  TestbedRouterP.Get -> CXRouterC.Get[NS_ROUTER];
  
}
