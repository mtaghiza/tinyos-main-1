configuration TestAppC{
} implementation {
  components MainC;
  components TestP;
  components SerialPrintfC;
  components PlatformSerialC;
  components new TimerMilliC();

  TestP.Boot -> MainC;
  TestP.SerialControl -> PlatformSerialC;
  TestP.UartStream -> PlatformSerialC;
  TestP.Timer -> TimerMilliC;
  

  components SamplerC;
  TestP.Sampler -> SamplerC;
  TestP.SamplerControl -> SamplerC;
  SamplerC.AdcConfigure -> TestP;

}

