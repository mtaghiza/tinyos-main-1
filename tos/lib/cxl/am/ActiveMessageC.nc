
  #ifndef HAS_ACTIVE_MESSAGE
  #define HAS_ACTIVE_MESSAGE
  #endif
configuration ActiveMessageC{
  provides interface SplitControl;
  provides interface AMSend[uint8_t client];
  provides interface Receive[am_id_t id];
  provides interface Receive as Snoop[am_id_t id];

  provides interface Packet;
  provides interface AMPacket;
  provides interface PacketAcknowledgements as Acks;

  provides interface Pool<message_t>;
  provides interface CTS;

} implementation {
  components CXActiveMessageC as AM;

  SplitControl = AM.SplitControl;
  AMSend = AM.AMSend;
  Receive = AM.Receive;
  Snoop = AM.Snoop;
  Packet = AM.Packet;
  AMPacket = AM.AMPacket;
  Acks = AM.Acks;
  CTS = AM.CTS;
  
  #ifndef AM_POOL_SIZE 
  #define AM_POOL_SIZE 4
  #endif
  components new PoolC(message_t, AM_POOL_SIZE);
  AM.Pool -> PoolC;
  Pool = PoolC;
}
