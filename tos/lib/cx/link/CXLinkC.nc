
 #include "CXLink.h"
configuration CXLinkC {
  provides interface SplitControl;
  provides interface CXRequestQueue;

  //for debug only
  provides interface Rf1aStatus;
  provides interface Rf1aPacket;
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

  //TODO: FIXME put into packet stack component
  components new Rf1aIeee154PacketC();
  CXLinkP.Rf1aPacket -> Rf1aIeee154PacketC.Rf1aPacket;
  Rf1aPacket = Rf1aIeee154PacketC;

  //for debug only
  Rf1aStatus = Rf1aPhysicalC;
}
