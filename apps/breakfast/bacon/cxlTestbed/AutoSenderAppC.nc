configuration AutoSenderAppC{
} implementation {
  components SerialPrintfC;
  components WatchDogC;
  components StackGuardMilliC;
  components MainC;
  components ActiveMessageC;
  components CXBaseStationC;
  BaseStationP.CXDownload -> CXBaseStationC.CXDownload;
  BaseStationP.StatusReceive -> CXBaseStationC.StatusReceive;

  //TODO: switch based on subnetwork being tested
  components new RouterAMSenderC(AM_TEST_MSG) as AMSender;
  components new SubNetworkAMSenderC(AM_TEST_MSG) as AMSender;
  components new GlobalAMSenderC(AM_TEST_MSG) as AMSender;

  BaseStationP.Send -> AMSender;

}
