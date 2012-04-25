configuration SamplerC{
  provides interface Sampler;
  provides interface SplitControl;
  uses interface AdcConfigure<const msp430adc12_channel_config_t*>;
} implementation{
  components SamplerP;

  components new Msp430Adc12ClientAutoRVGC() as AdcClient;
  SamplerP.Resource -> AdcClient.Resource;
  SamplerP.Msp430Adc12SingleChannel ->
    AdcClient.Msp430Adc12SingleChannel;
  SamplerP.Msp430Adc12Overflow ->
    AdcClient.Msp430Adc12Overflow;

  AdcClient.AdcConfigure = AdcConfigure;
  SamplerP.AdcConfigure = AdcConfigure;

  SplitControl = SamplerP;
  Sampler = SamplerP;

}
