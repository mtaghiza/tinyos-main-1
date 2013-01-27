configuration BusC {
  uses interface Pool<message_t>;
  //local address of currently-selected toast board
  provides interface Get<uint8_t>;
} implementation {
  components BusP;
  components MDActiveMessageC as ActiveMessageC;
  BusP.Pool = Pool;
  BusP.Packet -> ActiveMessageC;
  BusP.AMPacket -> ActiveMessageC;
  Get = BusP.Get;

  components new BusPowerClientC();
  BusP.BusControl -> BusPowerClientC;

  components new I2CDiscovererC();
  BusP.I2CDiscoverer -> I2CDiscovererC;

  components new MDAMReceiverC(AM_SCAN_BUS_CMD_MSG) as ScanBusCmdReceive;
  BusP.ScanBusCmdReceive -> ScanBusCmdReceive;
  components new MDAMReceiverC(AM_SET_BUS_POWER_CMD_MSG) as SetBusPowerCmdReceive;
  BusP.SetBusPowerCmdReceive -> SetBusPowerCmdReceive;
  components new MDAMSenderC(AM_SCAN_BUS_RESPONSE_MSG) as ScanBusResponseSend;
  BusP.ScanBusResponseSend -> ScanBusResponseSend;
  components new MDAMSenderC(AM_SET_BUS_POWER_RESPONSE_MSG) as SetBusPowerResponseSend;
  BusP.SetBusPowerResponseSend -> SetBusPowerResponseSend;
}
