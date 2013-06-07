 #include "RebootCounter.h"
generic configuration BaconSamplerC(volume_id_t VOLUME_ID, bool
circular) {
} implementation {
  components BaconSamplerP;

  components SettingsStorageC;

  components MainC;
  components new TimerMilliC();
  
  BaconSamplerP.Boot -> MainC;
  BaconSamplerP.Timer -> TimerMilliC;
  BaconSamplerP.SettingsStorage -> SettingsStorageC;

  components Apds9007C;
  BaconSamplerP.LightRead -> Apds9007C.Read;
  BaconSamplerP.LightControl -> Apds9007C.StdControl;

  components BatteryVoltageC;
  BaconSamplerP.BatteryRead -> BatteryVoltageC.Read;
  BaconSamplerP.BatteryControl -> BatteryVoltageC.StdControl;

  components new LogStorageC(VOLUME_ID, circular);
  BaconSamplerP.LogWrite -> LogStorageC;

  components LedsC;
  BaconSamplerP.Leds->LedsC;
}
