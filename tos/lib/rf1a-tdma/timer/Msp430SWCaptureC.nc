generic configuration Msp430SWCaptureC(){
  provides interface SWCapture;
} implementation {
  //if this overflows too fast, use 32khz!
  components new Msp430TimerMicroC() as Timer;
//  components new Msp430Timer32khzC() as Timer;
  components new Msp430SWCaptureP();
  components MainC;

  MainC.SoftwareInit -> Msp430SWCaptureP;
  Msp430SWCaptureP.Msp430Timer -> Timer;
  Msp430SWCaptureP.Msp430TimerControl -> Timer;
  Msp430SWCaptureP.Msp430Capture -> Timer;

  SWCapture = Msp430SWCaptureP;
}

