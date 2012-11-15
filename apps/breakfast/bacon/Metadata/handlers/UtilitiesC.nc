configuration UtilitiesC{
  uses interface Pool<message_t>;
} implementation{
  components UtilitiesP;
  components SerialActiveMessageC;
  UtilitiesP.Pool = Pool;
  UtilitiesP.Packet -> SerialActiveMessageC;

  components new SerialAMReceiverC(AM_PING_CMD_MSG) as PingCmdReceive;
  UtilitiesP.PingCmdReceive -> PingCmdReceive;
  components new SerialAMSenderC(AM_PING_RESPONSE_MSG) as PingResponseSend;
  UtilitiesP.PingResponseSend -> PingResponseSend;
}
