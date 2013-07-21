
 #include "ToastSampler.h"
generic configuration ToastSamplerC(volume_id_t VOLUME_ID, bool circular){
} implementation {
  components ToastSamplerP;
  components MainC;
  components new TimerMilliC();
  components new TimerMilliC() as StartupTimer;

  ToastSamplerP.Boot -> MainC;
  ToastSamplerP.Timer -> TimerMilliC;
  ToastSamplerP.StartupTimer -> StartupTimer;

  //result storage
  components new LogStorageC(VOLUME_ID, circular);
  ToastSamplerP.LogWrite -> LogStorageC;
  
  components DummyToastP;
  ToastSamplerP.SplitControl -> DummyToastP;
  ToastSamplerP.I2CDiscoverer -> DummyToastP;
  ToastSamplerP.I2CTLVStorageMaster -> DummyToastP;
  ToastSamplerP.I2CADCReaderMaster -> DummyToastP;
  ToastSamplerP.I2CSynchMaster -> DummyToastP;
  
  components new TLVUtilsC(SLAVE_TLV_LEN);
  ToastSamplerP.TLVUtils -> TLVUtilsC;
  DummyToastP.TLVUtils -> TLVUtilsC;

  //sampling settings
  components SettingsStorageC;
  ToastSamplerP.SettingsStorage -> SettingsStorageC;

  components CXAMAddressC;
  DummyToastP.ActiveMessageAddress -> CXAMAddressC;

  components RebootCounterC;

  components LocalTime32khzC;
  DummyToastP.LocalTime -> LocalTime32khzC;
  DummyToastP.Boot -> MainC;
}
