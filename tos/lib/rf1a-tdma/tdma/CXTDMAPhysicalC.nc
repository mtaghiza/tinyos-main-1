configuration CXTDMAPhysicalC {
  provides interface SplitControl;
  provides interface CXTDMA;

  uses interface HplMsp430Rf1aIf;
  uses interface Resource;
  uses interface Rf1aPhysical;
  uses interface Rf1aPhysicalMetadata;
  uses interface Rf1aStatus;
  uses interface Rf1aPacket;

} implementation {
  components CXTDMAPhysicalP;

  SplitControl = CXTDMAPhysicalP;
  CXTDMA = CXTDMAPhysicalP;

  HplMsp430Rf1aIf = CXTDMAPhysicalP;
  Resource = CXTDMAPhysicalP;
  Rf1aPhysical = CXTDMAPhysicalP;
  Rf1aPhysicalMetadata = CXTDMAPhysicalP;
  Rf1aStatus = CXTDMAPhysicalP;
  Rf1aPacket = CXTDMAPhysicalP;

  //TODO: Msp430Capture
  components new AlarmMicro32C() as FrameStartAlarm;
  components new AlarmMicro32C() as PrepareFrameStartAlarm;
  //This could be 32khz, not so important
  components new AlarmMicro32C() as FrameWaitAlarm;

  components GDO1CaptureC;

  CXTDMAPhysicalP.FrameStartAlarm -> FrameStartAlarm;
  CXTDMAPhysicalP.PrepareFrameStartAlarm -> PrepareFrameStartAlarm;
  CXTDMAPhysicalP.FrameWaitAlarm -> FrameWaitAlarm;
  CXTDMAPhysicalP.SynchCapture -> GDO1CaptureC;
}
