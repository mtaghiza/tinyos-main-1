#include "StorageVolumes.h"

configuration InitTestbedAppC {}

implementation
{
  components SerialPrintfC,
             PlatformSerialC;
  components InitTestbedP,
             MainC,
             new LogStorageC(VOLUME_RECORD, TRUE),
             LedsC;
             
  InitTestbedP.Boot -> MainC;
  InitTestbedP.Leds -> LedsC;
  //FormatFlashP.LogRead -> LogStorageC;
  InitTestbedP.LogWrite -> LogStorageC;
  InitTestbedP.UartCtl -> PlatformSerialC;
  InitTestbedP.UartStream -> PlatformSerialC;

  components new TimerMilliC();
  InitTestbedP.Timer -> TimerMilliC;

  components RebootCounterC;
  InitTestbedP.RebootCounter -> RebootCounterC;

  components SettingsStorageC;
 
  components new DummyLogWriteC();
  SettingsStorageC.LogWrite -> DummyLogWriteC;
  InitTestbedP.SettingsStorage -> SettingsStorageC;
}
