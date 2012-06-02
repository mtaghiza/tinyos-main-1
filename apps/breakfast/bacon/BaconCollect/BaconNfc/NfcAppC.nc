#include "StorageVolumes.h"
#include "baconCollect.h"

configuration NfcAppC{
} implementation {
  components NfcP as TestP;

  components MainC, LedsC;
  TestP.Boot -> MainC;
  TestP.Leds -> LedsC;

  components RandomC;
  MainC.SoftwareInit -> RandomC;
  TestP.Random -> RandomC;
  
  /* timers */
  components new TimerMilliC() as StatusTimer;
  TestP.StatusTimer -> StatusTimer;

  components new TimerMilliC() as WDTResetTimer;
  TestP.WDTResetTimer -> WDTResetTimer;

  components new TimerMilliC() as LedsTimer;
  TestP.LedsTimer -> LedsTimer;

  /* UART */
  components PlatformSerialC;
  components SerialPrintfC;
  TestP.SerialControl -> PlatformSerialC;
  TestP.UartStream -> PlatformSerialC;

  /* Radio */
  components ActiveMessageC;
  TestP.RadioControl -> ActiveMessageC;
  TestP.Packet -> ActiveMessageC;

  components new AMSenderC(CONTROL_CHANNEL) as ControlSend;
  TestP.ControlSend -> ControlSend;



}
