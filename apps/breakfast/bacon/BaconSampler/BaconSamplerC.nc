generic configuration BaconSamplerC(volume_id_t VOLUME_ID, 
    bool circular) {
} implementation {
  components new BaconSamplerHighC(VOLUME_ID, circular);
}
