configuration UAVSamplerC{
} implementation {
  components MainC;
  components UAVSamplerP;
  components SerialPrintfC;
  components PlatformSerialC;
  components new TimerMilliC();

  UAVSamplerP.Boot -> MainC;
  UAVSamplerP.SerialControl -> PlatformSerialC;
  UAVSamplerP.UartStream -> PlatformSerialC;
  UAVSamplerP.Timer -> TimerMilliC;
  

  components SamplerC;
  UAVSamplerP.Sampler -> SamplerC;
  UAVSamplerP.SamplerControl -> SamplerC;
  SamplerC.AdcConfigure -> UAVSamplerP;

}

