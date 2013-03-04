
 #include "CXTDMADebug.h"
configuration CXTDMAPhysicalC {
  provides interface SplitControl;
  provides interface CXTDMA;
  provides interface TDMAPhySchedule;
  provides interface FrameStarted;

  provides interface Rf1aPhysicalMetadata;

} implementation {
  components CXTDMAPhysicalP;

  components CXPacketStackC;

  SplitControl = CXTDMAPhysicalP;
  CXTDMA = CXTDMAPhysicalP;
  TDMAPhySchedule = CXTDMAPhysicalP;

  FrameStarted = CXTDMAPhysicalP;


  components new AlarmMicro32C() as FrameStartAlarm;
  components new AlarmMicro32C() as PrepareFrameStartAlarm;
  //This could be 32khz, not so important
  components new AlarmMicro32C() as FrameWaitAlarm;

  components RandomC;

  components GDO1CaptureC;
  
  #if DEBUG_CONFIG == 1
  components Rf1aDumpConfigC;
  CXTDMAPhysicalP.Rf1aDumpConfig -> Rf1aDumpConfigC;
  #endif

  CXTDMAPhysicalP.FrameStartAlarm -> FrameStartAlarm;
  CXTDMAPhysicalP.PrepareFrameStartAlarm -> PrepareFrameStartAlarm;
  CXTDMAPhysicalP.FrameWaitAlarm -> FrameWaitAlarm;
  CXTDMAPhysicalP.SynchCapture -> GDO1CaptureC;

  components CXRadioStateTimingC;
  CXTDMAPhysicalP.StateTiming -> CXRadioStateTimingC;


  components new Rf1aPhysicalC();

//  components SRFS7_915_GFSK_1P2K_SENS_HC;
//  components SRFS7_915_GFSK_4P8K_SENS_HC;
//  components SRFS7_915_GFSK_50K_SENS_HC;
//  components SRFS7_915_GFSK_100K_SENS_HC;
  components SRFS7_915_GFSK_125K_SENS_HC;
//  components SRFS7_915_GFSK_125K_SENS_FIXED_HC;
//  components SRFS7_915_GFSK_175K_SENS_HC;
//  components SRFS7_915_GFSK_250K_SENS_HC;

//  CXTDMAPhysicalP.SubRf1aConfigure[1]   -> SRFS7_915_GFSK_1P2K_SENS_HC;
//  CXTDMAPhysicalP.SubRf1aConfigure[5]   -> SRFS7_915_GFSK_4P8K_SENS_HC;
//  CXTDMAPhysicalP.SubRf1aConfigure[50]  -> SRFS7_915_GFSK_50K_SENS_HC;
//  CXTDMAPhysicalP.SubRf1aConfigure[100] -> SRFS7_915_GFSK_100K_SENS_HC;
  #if CX_FIXED_LEN == 1
  CXTDMAPhysicalP.SubRf1aConfigure[125] -> SRFS7_915_GFSK_125K_SENS_FIXED_HC;
  #else
  CXTDMAPhysicalP.SubRf1aConfigure[125] -> SRFS7_915_GFSK_125K_SENS_HC;
  #endif
//  CXTDMAPhysicalP.SubRf1aConfigure[175] -> SRFS7_915_GFSK_175K_SENS_HC;
//  CXTDMAPhysicalP.SubRf1aConfigure[250] -> SRFS7_915_GFSK_250K_SENS_HC;

  Rf1aPhysicalC.Rf1aConfigure -> CXTDMAPhysicalP.Rf1aConfigure;

  CXTDMAPhysicalP.HplMsp430Rf1aIf -> Rf1aPhysicalC;
  CXTDMAPhysicalP.Resource -> Rf1aPhysicalC;
  CXTDMAPhysicalP.Rf1aPhysical -> Rf1aPhysicalC;
  CXTDMAPhysicalP.Rf1aPhysicalMetadata -> Rf1aPhysicalC;
  CXTDMAPhysicalP.Rf1aStatus -> Rf1aPhysicalC;
  CXTDMAPhysicalP.Rf1aPacket -> CXPacketStackC.Rf1aPacket;
  CXTDMAPhysicalP.Packet -> CXPacketStackC.Ieee154PacketBody;
  CXTDMAPhysicalP.CXPacket -> CXPacketStackC.CXPacket;
  CXTDMAPhysicalP.CXPacketMetadata -> CXPacketStackC.CXPacketMetadata;
  CXTDMAPhysicalP.DelayedSend -> Rf1aPhysicalC.DelayedSend;

  CXTDMAPhysicalP.Random -> RandomC;

  Rf1aPhysicalMetadata = Rf1aPhysicalC;
}
