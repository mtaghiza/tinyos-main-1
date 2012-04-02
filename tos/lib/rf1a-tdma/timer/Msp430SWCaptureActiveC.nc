generic configuration Msp430SWCaptureActiveC(){
  provides interface SWCaptureActive;
} implementation {
  //if this overflows too fast, use 32khz!
  components new Msp430TimerMicroC();
  components new Msp430SWCaptureActiveP();
  components MainC;

  MainC.SoftwareInit -> Msp430SWCaptureActiveP;
  Msp430SWCaptureActiveP.Msp430Timer -> Msp430TimerMicroC;
  Msp430SWCaptureActiveP.Msp430TimerControl -> Msp430TimerMicroC;
  Msp430SWCaptureActiveP.Msp430Capture -> Msp430TimerMicroC;

  SWCapture = Msp430SWCaptureActiveP;
}
