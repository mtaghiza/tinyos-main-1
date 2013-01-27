generic configuration MDAMReceiverC(am_id_t AMId){
  provides interface Receive;
  provides interface Packet;
  provides interface AMPacket;
} implementation {
  #if USE_AM_RADIO == 1
  components new AMReceiverC(AMId) as AMReceiver;
  #else
  components new SerialAMReceiverC(AMId) as AMReceiver;
  #endif

  Receive = AMReceiver;
  Packet = AMReceiver;
  AMPacket = AMReceiver;
}
