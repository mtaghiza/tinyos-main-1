configuration CXLinkC {
  provides interface SplitControl;
  provides interface Receive;
  provides interface Send;
  provides interface CXLink;
  provides interface CXLinkPacket;
  provides interface Packet;

  uses interface Pool<message_t>;
  provides interface Rf1aStatus;
} implementation {
  components CXLinkP;
  SplitControl = CXLinkP.SplitControl;
  Receive = CXLinkP.Receive;
  Send = CXLinkP.Send;
  CXLink = CXLinkP.CXLink;
  CXLinkP.Pool = Pool;

  components new Rf1aPhysicalC();
  CXLinkP.Rf1aPhysical -> Rf1aPhysicalC;
  CXLinkP.Resource -> Rf1aPhysicalC;
  CXLinkP.DelayedSend -> Rf1aPhysicalC;
  CXLinkP.Rf1aPhysicalMetadata -> Rf1aPhysicalC;

  components SRFS7_915_GFSK_125K_SENS_HC as RadioConfigC;
  Rf1aPhysicalC.Rf1aConfigure -> RadioConfigC;

  Rf1aStatus = Rf1aPhysicalC;

  components GDO1CaptureC;
  CXLinkP.SynchCapture -> GDO1CaptureC;

  components new AlarmMicro32C() as FastAlarm;
  CXLinkP.FastAlarm -> FastAlarm;
  components LocalTime32khzC;
  CXLinkP.LocalTime -> LocalTime32khzC; 

  components Msp430XV2ClockC;
  CXLinkP.Msp430XV2ClockControl -> Msp430XV2ClockC;
  
  components CXLinkPacketC;
  CXLinkP.Packet -> CXLinkPacketC.Packet;
  CXLinkP.CXLinkPacket -> CXLinkPacketC.CXLinkPacket;
  Packet = CXLinkPacketC.Packet;
  CXLinkPacket = CXLinkPacketC.CXLinkPacket;

  components CXAMAddressC;
  CXLinkP.ActiveMessageAddress -> CXAMAddressC;

}

