
 #include "testbed.h"
 #include "autosender.h"
configuration TestbedLeafC{
} implementation {
  components TestbedLeafP;
  components SlotSchedulerC;
  components CXLeafC;
  components new SubNetworkAMSenderC(AM_TEST_MSG) as AMSenderC;
  
  TestbedLeafP.DownloadNotify -> SlotSchedulerC.DownloadNotify[NS_SUBNETWORK];
  TestbedLeafP.AMSend -> AMSenderC;
  TestbedLeafP.Get -> CXLeafC.Get[NS_SUBNETWORK];

  components ActiveMessageC;
  components CXLinkPacketC;
  TestbedLeafP.Pool -> ActiveMessageC;
  TestbedLeafP.CXLinkPacket -> CXLinkPacketC;
}
