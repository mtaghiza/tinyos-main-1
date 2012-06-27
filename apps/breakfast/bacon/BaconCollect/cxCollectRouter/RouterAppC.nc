#include "StorageVolumes.h"
#include "baconCollect.h"
#include "test.h"
#include "CXTransport.h"

configuration RouterAppC{
} implementation {
  components RouterP as TestP;

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

  /***************************************************************************/
  /* Radio */

  components ActiveMessageC;
  TestP.RadioControl -> ActiveMessageC;
  TestP.Packet -> ActiveMessageC;
  TestP.Rf1aPacket -> ActiveMessageC;  
  TestP.AMPacket -> ActiveMessageC;
//  TestP.PacketAcknowledgements -> ActiveMessageC;
//  TestP.PhysicalControl -> Rf1aActiveMessageC.PhysicalControl;

  components new AMReceiverC(PERIODIC_CHANNEL) as PeriodicReceiveC;
  TestP.PeriodicReceive -> PeriodicReceiveC;

  components new CXAMSenderC(CONTROL_CHANNEL, CX_TP_RELIABLE_BURST) as ControlSendC;
  TestP.ControlSend -> ControlSendC;
  
  components new AMReceiverC(CONTROL_CHANNEL) as ControlReceiveC;
  TestP.ControlReceive -> ControlReceiveC;

  components new AMReceiverC(MASTER_CONTROL_CHANNEL) as MasterControlReceiveC;
  TestP.MasterControlReceive -> MasterControlReceiveC;


  /***************************************************************************/

  components new PoolC(message_t, SEND_POOL_SIZE);
  TestP.Pool -> PoolC;

  components new QueueC(message_t*, SEND_POOL_SIZE);
  TestP.Queue -> QueueC;

  /***************************************************************************/
  /* pins */  
  components HplMsp430GeneralIOC;
  TestP.CS -> HplMsp430GeneralIOC.Port11;
  TestP.CD -> HplMsp430GeneralIOC.Port24;
  TestP.FlashEnable -> HplMsp430GeneralIOC.Port21;

}
