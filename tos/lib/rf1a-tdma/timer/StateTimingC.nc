generic configuration StateTimingC(uint8_t numStates, 
    uint8_t initialState){
  provides interface StateTiming;
} implementation {
  components new Msp430SWCaptureC();
  components new StateTimingP(numStates, initialState);
  
  StateTimingP.SWCapture -> Msp430SWCaptureC;

  StateTiming = StateTimingP;
}
