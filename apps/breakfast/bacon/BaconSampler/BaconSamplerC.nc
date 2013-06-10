generic configuration BaconSamplerC(volume_id_t VOLUME_ID, 
    bool circular) {
} implementation {
  #ifndef BACON_SAMPLER_HIGH
  #define BACON_SAMPLER_HIGH 0
  #endif

  #if BACON_SAMPLER_HIGH == 1
  #warning Using BaconSamplerHigh
  components new BaconSamplerHighC(VOLUME_ID, circular);
  #else
  components new BaconSamplerLowC(VOLUME_ID, circular);
  #endif
}
