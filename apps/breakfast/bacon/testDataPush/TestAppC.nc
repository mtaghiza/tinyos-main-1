#include "StorageVolumes.h"

configuration TestAppC{
} implementation {
  components TestP;

  components MainC, LedsC, new TimerMilliC();
  TestP.Boot -> MainC;
  TestP.Leds -> LedsC;
  TestP.Timer -> TimerMilliC;

  components WatchDogC;

  components PlatformSerialC;
  components SerialPrintfC;
  TestP.SerialControl -> PlatformSerialC;
  TestP.UartStream -> PlatformSerialC;

  components new LogStorageC(VOLUME_TEST, TRUE);
  TestP.LogRead -> LogStorageC.LogRead;
  TestP.LogWrite -> LogStorageC.LogWrite;

  components new LogNotifyC(VOLUME_TEST);
  TestP.LogNotify -> LogNotifyC;

}
