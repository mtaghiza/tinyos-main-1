 #include "StorageVolumes.h"
configuration MinLeafAppC{
} implementation {
  components MainC;
  components MinLeafP;
  components CXLeafC;
  components ActiveMessageC;

  MinLeafP.SplitControl -> ActiveMessageC;
  MinLeafP.Boot -> MainC;
  components new TimerMilliC();
  MinLeafP.Timer -> TimerMilliC;
  
  components SettingsStorageC;
  components new LogStorageC(VOLUME_RECORD, TRUE) as SettingsLS;
  SettingsStorageC.LogWrite -> SettingsLS;

  #if ENABLE_PHOENIX == 1
  components PhoenixNeighborhoodP;
  components new LogStorageC(VOLUME_RECORD, TRUE) as PhoenixLS;
  PhoenixNeighborhoodP.LogWrite -> PhoenixLS;
  #endif

  components new ToastSamplerC(VOLUME_RECORD, TRUE);
  components new BaconSamplerC(VOLUME_RECORD, TRUE);
}
