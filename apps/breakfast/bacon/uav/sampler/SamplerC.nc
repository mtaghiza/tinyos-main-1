configuration SamplerC{
  provides interface Sampler;
  provides interface SplitControl;
  uses interface AdcConfigure<const msp430adc12_channel_config_t*>;
} implementation{
  components SamplerP;
  components LedsC;

  components new Msp430Adc12ClientAutoRVGC() as AdcClient;
  SamplerP.ADCResource -> AdcClient.Resource;
  SamplerP.Msp430Adc12SingleChannel ->
    AdcClient.Msp430Adc12SingleChannel;
  SamplerP.Msp430Adc12Overflow ->
    AdcClient.Msp430Adc12Overflow;

  AdcClient.AdcConfigure = AdcConfigure;
  SamplerP.AdcConfigure = AdcConfigure;

  SplitControl = SamplerP;
  Sampler = SamplerP;

  components SDCardC as SDCardC;
  SamplerP.SDResource -> SDCardC;
  SamplerP.SDCard -> SDCardC;
  SamplerP.Leds -> LedsC;

}
