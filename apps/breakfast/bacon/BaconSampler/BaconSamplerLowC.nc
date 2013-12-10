 #include "RebootCounter.h"
generic configuration BaconSamplerLowC(volume_id_t VOLUME_ID, bool
circular){
} implementation {
  components BaconSamplerLowP as BaconSamplerP;
  components SettingsStorageC;
  components MainC;
  components new TimerMilliC();
  components new TimerMilliC() as WarmupTimer;
  BaconSamplerP.Boot -> MainC;
  BaconSamplerP.Timer -> TimerMilliC;
  BaconSamplerP.WarmupTimer -> WarmupTimer;
  BaconSamplerP.SettingsStorage -> SettingsStorageC;

  components new LogStorageC(VOLUME_ID, circular);
//  components new DummyLogWriteC() as LogStorageC;
  BaconSamplerP.LogWrite -> LogStorageC;
}
