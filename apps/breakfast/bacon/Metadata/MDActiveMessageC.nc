
#ifndef USE_AM_RADIO
#define USE_AM_RADIO 0
#endif

configuration MDActiveMessageC{
  provides interface SplitControl;
  provides interface AMSend[am_id_t id];
  provides interface Receive[am_id_t id];
  
  #if USE_AM_RADIO == 1
  provides interface Receive as Snoop[am_id_t id];
  provides interface LowPowerListening;
  #endif

  provides interface Packet;
  provides interface AMPacket;
  provides interface PacketAcknowledgements;
} implementation {
  #if USE_AM_RADIO == 1
  components ActiveMessageC as AM;
  Snoop        = AM.Snoop;
  LowPowerListening = AM;
  #else 
  components SerialActiveMessageC as AM;
  #endif

  SplitControl = AM;
  AMSend       = AM;
  Receive      = AM.Receive;
  Packet       = AM;
  AMPacket     = AM;
  PacketAcknowledgements = AM;
}
