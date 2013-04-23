
 #include "CXLink.h"
configuration CXLinkC {
  provides interface SplitControl;
  provides interface CXRequestQueue;
  
  provides interface CXLinkPacket;
  provides interface Packet;
  provides interface Rf1aPacket;
  //for debug only
  provides interface Rf1aStatus;
} implementation {
  components CXLinkP;

  components GDO1CaptureC;
  components new AlarmMicro32C() as FastAlarm;
  components new Timer32khzC() as FrameTimer;
  components Msp430XV2ClockC;
  CXLinkP.FastAlarm -> FastAlarm;
  CXLinkP.FrameTimer -> FrameTimer;
  CXLinkP.SynchCapture -> GDO1CaptureC;
  CXLinkP.Msp430XV2ClockControl -> Msp430XV2ClockC;

  components new Rf1aPhysicalC();
  CXLinkP.Rf1aPhysical -> Rf1aPhysicalC;
  CXLinkP.Rf1aPhysicalMetadata -> Rf1aPhysicalC;
  CXLinkP.DelayedSend -> Rf1aPhysicalC;
  CXLinkP.Resource -> Rf1aPhysicalC;
  Rf1aPhysicalC.Rf1aTransmitFragment -> CXLinkP;

  components SRFS7_915_GFSK_125K_SENS_HC as RadioConfigC;
  Rf1aPhysicalC.Rf1aConfigure -> RadioConfigC;
  //TODO: FUTURE wire up a channel cache if desired

  components new PoolC(cx_request_t, REQUEST_QUEUE_LEN);
  components new PriorityQueueC(cx_request_t*, REQUEST_QUEUE_LEN);
  CXLinkP.Pool -> PoolC;
  CXLinkP.Queue -> PriorityQueueC;
  PriorityQueueC.Compare -> CXLinkP;

  SplitControl = CXLinkP;
  CXRequestQueue = CXLinkP;

  components MainC;
  CXLinkP.Boot -> MainC;

  components CXLinkPacketC;
  CXLinkP.Rf1aPacket -> CXLinkPacketC.Rf1aPacket;
  CXLinkP.Packet -> CXLinkPacketC.Packet;
  Packet = CXLinkPacketC.Packet;
  Rf1aPacket = CXLinkPacketC.Rf1aPacket;
  CXLinkPacket = CXLinkPacketC;
  CXLinkPacketC.Rf1aPhysicalMetadata -> Rf1aPhysicalC;

  components CXPacketMetadataC;
  CXLinkP.CXPacketMetadata -> CXPacketMetadataC;

  //for debug only
  Rf1aStatus = Rf1aPhysicalC;
}
