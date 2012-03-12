configuration GDO1CaptureC{
  provides interface GpioCapture as Capture;
} implementation {
  components GDO1CaptureP;
  components Msp430TimerC;
  components new Msp430InternalCaptureP();
  
  Capture = Msp430InternalCaptureP;
  Msp430InternalCaptureP.Msp430TimerControl -> Msp430TimerC.Control0_A3;
  Msp430InternalCaptureP.Msp430Capture -> Msp430TimerC.Capture0_A3;
  Msp430InternalCaptureP.GetCCIS -> GDO1CaptureP;
}
