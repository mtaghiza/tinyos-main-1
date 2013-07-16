 #include "StorageVolumes.h"
 #include "message.h"
 #include "CXDebug.h"
configuration LeafAppC{
} implementation {
  #if ENABLE_PRINTF == 1
  components SerialPrintfC;
  components SerialStartC;
  #endif

  components WatchDogC;
  #ifndef NO_STACKGUARD
  components StackGuardMilliC;
  #endif

  components MainC;
  components LeafP;

  #if PHOENIX_LOGGING == 1
  //yeesh this is ugly
  components PhoenixNeighborhoodP;
  components new LogStorageC(VOLUME_RECORD, TRUE);
  PhoenixNeighborhoodP.LogWrite -> LogStorageC;
  #endif

  components ActiveMessageC;

  components SettingsStorageConfiguratorC;
  SettingsStorageConfiguratorC.Pool -> ActiveMessageC.Pool;

  LeafP.SplitControl -> ActiveMessageC;
  LeafP.Boot -> MainC;

}
