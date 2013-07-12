interface LppProbeSniffer{
  command error_t sniff(uint8_t networkSegment);
  event void sniffDone(error_t error);
  event message_t* sniffProbe(message_t* msg);
}
