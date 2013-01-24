configuration DualActiveMessageC {
  provides {
    interface SplitControl;

    interface AMSend[am_id_t id];
    interface Receive[am_id_t id];
    interface Receive as Snoop[am_id_t id];

    interface Packet;
    interface AMPacket;
    interface PacketAcknowledgements;
    interface LowPowerListening;
  }
} implementation {
  components DualActiveMessageP;

  components SerialActiveMessageC as SerialAM;
  components RadioActiveMessageC as RadioAM;

  //Radio-specific
  Snoop        = RadioAM.Snoop;
  LowPowerListening = RadioAM;

  //shared: pass-through/combine
  Receive      = SerialAM.Receive;
  Receive      = RadioAM.Receive;

  //shared: requires logic
  AMSend       = DualActiveMessageP;
  DualActiveMessageP.SerialAMSend -> SerialAM;
  DualActiveMessageP.RadioAMSend -> RadioAM;
 
  SplitControl = DualActiveMessageP;
  DualActiveMessageP.SerialSplitControl -> SerialAM;
  DualActiveMessageP.RadioSplitControl -> RadioAM;

  //present as radio, also used internally
  Packet       = RadioAM;
  DualActiveMessageP.RadioPacket -> RadioAM;
  DualActiveMessageP.SerialPacket -> SerialAM;
  AMPacket     = RadioAM;
  DualActiveMessageP.RadioAMPacket -> RadioAM;
  DualActiveMessageP.SerialAMPacket -> SerialAM;

  //radio-specific?
  PacketAcknowledgements = RadioAM;

}
