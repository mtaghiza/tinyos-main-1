generic configuration BaconSamplerC(volume_id_t VOLUME_ID, 
    bool circular) {
} implementation {
  #ifndef BACON_SAMPLER_DUMMY
  #define BACON_SAMPLER_DUMMY 0
  #endif

  #if BACON_SAMPLER_DUMMY == 1
  #warning Using DUMMY bacon sampler, DO NOT deploy
  components new BaconSamplerDummyC(VOLUME_ID, circular);
  #else
  components new BaconSamplerLowC(VOLUME_ID, circular);
  #endif
}
