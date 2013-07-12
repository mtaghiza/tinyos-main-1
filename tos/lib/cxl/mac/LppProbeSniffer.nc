interface LppProbeSniffer{
  command error_t sniff(uint32_t timeoutMilli);
  event void sniffDone(error_t error);
  event message_t* sniffProbe(message_t* msg);
}
