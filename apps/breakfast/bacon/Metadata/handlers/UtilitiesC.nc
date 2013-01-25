configuration UtilitiesC{
  uses interface Pool<message_t>;
} implementation{
  components UtilitiesP;
  components SerialActiveMessageC as ActiveMessageC;
  UtilitiesP.Pool = Pool;
  UtilitiesP.Packet -> ActiveMessageC;
  UtilitiesP.AMPacket -> ActiveMessageC;

  components new SerialAMReceiverC(AM_PING_CMD_MSG) as PingCmdReceive;
  UtilitiesP.PingCmdReceive -> PingCmdReceive;
  components new SerialAMSenderC(AM_PING_RESPONSE_MSG) as PingResponseSend;
  UtilitiesP.PingResponseSend -> PingResponseSend;
}
