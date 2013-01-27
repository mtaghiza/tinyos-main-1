generic configuration MDAMSenderC(am_id_t AMId){
  provides {
    interface AMSend;
    interface Packet;
    interface AMPacket;
    interface PacketAcknowledgements as Acks;
  }
} implementation{
  #if USE_AM_RADIO == 1
  components new AMSenderC(AMId) as AMSender;
  #else
  components new SerialAMSenderC(AMId) as AMSender;
  #endif

  AMSend = AMSender;
  Packet = AMSender;
  AMPacket = AMSender;
  Acks = AMSender;
}
