configuration TestAppC{
} implementation {
  components MainC;
  components TestP;
  components SerialPrintfC;
  components PlatformSerialC;

  TestP.Boot -> MainC;
  TestP.SerialControl -> PlatformSerialC;
  TestP.UartStream -> PlatformSerialC;
  
  components SamplerC;
  TestP.Sampler -> SamplerC;
  TestP.SamplerControl -> SamplerC;
  SamplerC.AdcConfigure -> TestP;
//  components new Msp430Adc12ClientAutoRVGC() as AdcClient;
//  TestP.Resource -> AdcClient.Resource;
//  TestP.Msp430Adc12SingleChannel ->
//    AdcClient.Msp430Adc12SingleChannel;
//  TestP.Msp430Adc12Overflow ->
//    AdcClient.Msp430Adc12Overflow;
//
//  AdcClient.AdcConfigure -> TestP;

}
