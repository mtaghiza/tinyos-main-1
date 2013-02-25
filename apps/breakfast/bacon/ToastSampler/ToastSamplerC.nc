generic configuration ToastSamplerC(volume_id_t VOLUME_ID, bool circular){
} implementation {
  components ToastSamplerP;
  components MainC;
  components new TimerMilliC();

  ToastSamplerP.Boot -> MainC;
  ToastSamplerP.Timer -> TimerMilliC;

  //result storage
  components new LogStorageC(VOLUME_ID, circular);
  ToastSamplerP.LogWrite -> LogStorageC;
  
  //power/discovery
  components new BusPowerClientC();
  ToastSamplerP.SplitControl -> BusPowerClientC;
  components new I2CDiscovererC();
  ToastSamplerP.I2CDiscoverer -> I2CDiscovererC;
  
  //Metadata discovery
  components I2CTLVStorageMasterC;
  ToastSamplerP.I2CTLVStorageMaster -> I2CTLVStorageMasterC;
  ToastSamplerP.TLVUtils -> I2CTLVStorageMasterC;
  
  //sampling
  components I2CADCReaderMasterC;
  ToastSamplerP.I2CADCReaderMaster -> I2CADCReaderMasterC;

  //sampling settings
  components SettingsStorageC;
  ToastSamplerP.SettingsStorage -> SettingsStorageC;
}
