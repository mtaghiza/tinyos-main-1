
 #include "StorageVolumes.h"
configuration TestAppC{
} implementation {
  components new ToastSamplerC(VOLUME_RECORD, TRUE);
  components MainC;
  components TestP;

  components WatchDogC;

  components PrintfC;
  components SerialStartC;

  TestP.Boot -> MainC;

}
