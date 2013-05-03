 #include <stdio.h>
configuration TestSkewC{
} implementation {
  components MainC;
  components TestSkewP as TestP;
  
  components PlatformSerialC;
  components SerialPrintfC;

  TestP.Boot -> MainC;
  TestP.UartStream -> PlatformSerialC;
  
  TestP.SerialControl -> PlatformSerialC;
  
  components SkewCorrectionC;
  TestP.SkewCorrection -> SkewCorrectionC;
}
