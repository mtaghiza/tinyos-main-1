
 #include "StorageVolumes.h"
configuration TestAppC{
} implementation {
  components MainC;
  
  components PrintfC;
  components SerialStartC;
  components WatchDogC;

  components TestP;
  components new LogStorageC(VOLUME_TEST, TRUE);

  TestP.Boot -> MainC;
  TestP.LogWrite -> LogStorageC;
  TestP.LogRead -> LogStorageC;
}
