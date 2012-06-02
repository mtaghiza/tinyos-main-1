#include "StorageVolumes.h"
#include "baconCollect.h"

configuration GateAppC{
} implementation {
  components GateP as TestP;

  components MainC, LedsC;
  TestP.Boot -> MainC;
  TestP.Leds -> LedsC;

  components RandomC;
  MainC.SoftwareInit -> RandomC;
  TestP.Random -> RandomC;

  components CrcC;
  TestP.Crc -> CrcC;

  components new LogStorageC(VOLUME_SENSORLOG, TRUE);
  TestP.LogRead -> LogStorageC;
  TestP.LogWrite -> LogStorageC;
  
  
  /* timers */
  components new TimerMilliC() as StatusTimer;
  TestP.StatusTimer -> StatusTimer;

  components new TimerMilliC() as WDTResetTimer;
  TestP.WDTResetTimer -> WDTResetTimer;

  components new TimerMilliC() as ClockTimer;
  TestP.ClockTimer -> ClockTimer;

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
  TestP.PacketAcknowledgements -> ActiveMessageC;

  components new AMReceiverC(PERIODIC_CHANNEL) as PeriodicReceive;
  TestP.AMPacket -> PeriodicReceive;
  TestP.PeriodicReceive -> PeriodicReceive;

  components new AMSenderC(CONTROL_CHANNEL) as ControlSend;
  TestP.ControlSend -> ControlSend;
  components new AMReceiverC(CONTROL_CHANNEL) as ControlReceive;
  TestP.ControlReceive -> ControlReceive;

  components new AMReceiverC(MASTER_CONTROL_CHANNEL) as MasterControlReceive;
  TestP.MasterControlReceive -> MasterControlReceive;

  components Rf1aActiveMessageC;
  TestP.Rf1aPacket -> Rf1aActiveMessageC;
  TestP.PhysicalControl -> Rf1aActiveMessageC.PhysicalControl;

  components new PoolC(message_t, SEND_POOL_SIZE);
  TestP.Pool -> PoolC;

  components new QueueC(message_t*, SEND_POOL_SIZE);
  TestP.Queue -> QueueC;

  /* pins */  
  components HplMsp430GeneralIOC;
  TestP.CS -> HplMsp430GeneralIOC.Port11;
  TestP.CD -> HplMsp430GeneralIOC.Port24;
  TestP.FlashEnable -> HplMsp430GeneralIOC.Port21;

}
