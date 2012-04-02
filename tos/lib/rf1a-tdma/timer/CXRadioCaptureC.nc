configuration CXRadioCaptureC {
  provides interface SWCapture;
} implementation {
  components new Msp430SWCaptureC();
  
  SWCapture = Msp430SWCaptureC;
}
