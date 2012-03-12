configuration GDO2CaptureC{
  provides interface GpioCapture as Capture;
} implementation {
  components GDO2CaptureP;
  components Msp430TimerC;
  components new Msp430InternalCaptureP();
  
  Capture = Msp430InternalCaptureP;
  Msp430InternalCaptureP.Msp430TimerControl -> Msp430TimerC.Control0_A4;
  Msp430InternalCaptureP.Msp430Capture -> Msp430TimerC.Capture0_A4;
  Msp430InternalCaptureP.GetConfig -> GDO2CaptureP;
}
