configuration CXRadioStateTimingC{
  provides interface StateTiming;
} implementation {
  //See Rf1a.h: 9 radio states, start in OFFLINE (index =8)
  components new StateTimingC(9, 0x08);
  components CXRadioStateTimingP;
  
  CXRadioStateTimingP.SubStateTiming -> StateTimingC;
  StateTiming = CXRadioStateTimingP;
}
