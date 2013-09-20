 #include "RebootCounter.h"
generic configuration BaconSamplerDummyC(volume_id_t VOLUME_ID, bool
circular){
} implementation {
  components BaconSamplerDummyP as BaconSamplerP;
  components SettingsStorageC;
  components MainC;
  components new TimerMilliC();
  BaconSamplerP.Boot -> MainC;
  BaconSamplerP.Timer -> TimerMilliC;
  BaconSamplerP.SettingsStorage -> SettingsStorageC;

  components new LogStorageC(VOLUME_ID, circular);
  BaconSamplerP.LogWrite -> LogStorageC;
}
