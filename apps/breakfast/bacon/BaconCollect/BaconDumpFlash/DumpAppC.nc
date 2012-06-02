#include "StorageVolumes.h"
#include "baconCollect.h"

configuration DumpAppC{
} implementation {
  components DumpP as TestP;

  components MainC, LedsC;
  TestP.Boot -> MainC;
  TestP.Leds -> LedsC;

  components CrcC;
  TestP.Crc -> CrcC;

  components new LogStorageC(VOLUME_SENSORLOG, TRUE);
  TestP.LogRead -> LogStorageC;
  TestP.LogWrite -> LogStorageC;
  
  
  /* timers */
  components new TimerMilliC() as WDTResetTimer;
  TestP.WDTResetTimer -> WDTResetTimer;

  components new TimerMilliC() as LedsTimer;
  TestP.LedsTimer -> LedsTimer;

  /* UART */
  components PlatformSerialC;
  components SerialPrintfC;
  TestP.SerialControl -> PlatformSerialC;
  TestP.UartStream -> PlatformSerialC;

  /* pins */  
  components HplMsp430GeneralIOC;
  TestP.CS -> HplMsp430GeneralIOC.Port11;
  TestP.CD -> HplMsp430GeneralIOC.Port24;
  TestP.FlashEnable -> HplMsp430GeneralIOC.Port21;

}
