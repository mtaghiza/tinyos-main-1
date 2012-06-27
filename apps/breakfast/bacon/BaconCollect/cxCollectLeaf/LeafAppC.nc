#include "StorageVolumes.h"
#include "baconCollect.h"
#include "test.h"
#include "CXTransport.h"

configuration LeafAppC{
} implementation {
  components LeafP as TestP;

  components MainC;
  TestP.Boot -> MainC;


  components RandomC;
  MainC.SoftwareInit -> RandomC;
  TestP.Random -> RandomC;

  components CrcC;
  TestP.Crc -> CrcC;

  /* leds */
  components LedsC;
  TestP.Leds -> LedsC;

  components new TimerMilliC() as LedsTimer;
  TestP.LedsTimer -> LedsTimer;

  /* watchdog */
  components new TimerMilliC() as WDTResetTimer;
  TestP.WDTResetTimer -> WDTResetTimer;

  /***************************************************************************/
  /* sampling related                                                        */
  /***************************************************************************/

  /* bacon sensors */
#ifdef USE_BACON_ADC  
  components BatteryVoltageC;
  TestP.BatteryControl -> BatteryVoltageC;
  TestP.BatteryVoltage -> BatteryVoltageC;

  components Apds9007C;
  TestP.LightControl -> Apds9007C;
  TestP.Apds9007 -> Apds9007C;
  
  components Mcp9700C;
  TestP.TempControl -> Mcp9700C;
  TestP.Mcp9700 -> Mcp9700C;
#endif

  /* toast sensors */
  components new I2CDiscovererC();
  TestP.I2CDiscoverer -> I2CDiscovererC;

  components I2CADCReaderMasterC;
  TestP.I2CADCReaderMaster -> I2CADCReaderMasterC;
  
  /* timers */
#ifdef USE_BACON_ADC  
  components new TimerMilliC() as BaconSampleTimer;
  TestP.BaconSampleTimer -> BaconSampleTimer;
#endif

  components new TimerMilliC() as ToastSampleTimer;
  TestP.ToastSampleTimer -> ToastSampleTimer;

  components new TimerMilliC() as StatusSampleTimer;
  TestP.StatusSampleTimer -> StatusSampleTimer;



  /***************************************************************************/
  /* storage related                                                         */
  /***************************************************************************/

  /* flash */
  components new LogStorageC(VOLUME_SENSORLOG, TRUE);
  TestP.LogRead -> LogStorageC;
  TestP.LogWrite -> LogStorageC;

  components new PoolC(sample_t, SAMPLE_POOL_SIZE) as WritePool;
  TestP.WritePool -> WritePool;

  components new QueueC(sample_t*, SAMPLE_POOL_SIZE) as WriteQueue;
  TestP.WriteQueue -> WriteQueue;


  /* pins */  
  components HplMsp430GeneralIOC;
  TestP.CS -> HplMsp430GeneralIOC.Port10;
  TestP.FlashEnable -> HplMsp430GeneralIOC.Port21;
  TestP.ToastEnable -> HplMsp430GeneralIOC.Port37;

#ifdef DEBUG
  /* UART */
  components SerialPrintfC;

  components PlatformSerialC;
  TestP.SerialControl -> PlatformSerialC;
  TestP.UartStream -> PlatformSerialC;
#endif



  /***************************************************************************/
  /* cx related                                                         */
  /***************************************************************************/

  components ActiveMessageC;
  TestP.RadioControl -> ActiveMessageC;
  TestP.Packet -> ActiveMessageC;
  TestP.Rf1aPacket -> ActiveMessageC;  
  TestP.AMPacket -> ActiveMessageC;

  components new AMReceiverC(CONTROL_CHANNEL);
  TestP.ControlReceive -> AMReceiverC;

  components new CXAMSenderC(PERIODIC_CHANNEL, CX_TP_SIMPLE_FLOOD) as PeriodicSendC;
  TestP.PeriodicSend -> PeriodicSendC;

  components new CXAMSenderC(CONTROL_CHANNEL, CX_TP_SIMPLE_FLOOD) as ControlSendC;
  TestP.ControlSend -> ControlSendC;


  /***************************************************************************/
  /* radio related                                                           */
  /***************************************************************************/

  /* message buffer/queue */
  components new PoolC(message_t, SEND_POOL_SIZE) as SendPool;
  TestP.SendPool -> SendPool;

  components new QueueC(message_t*, SEND_POOL_SIZE) as SendQueue;
  TestP.SendQueue -> SendQueue;

  /* offload timer */
  components new TimerMilliC() as OffloadTimer;
  TestP.OffloadTimer -> OffloadTimer;

  /* transmit delay timer */
  components new TimerMilliC() as DelayTimer;
  TestP.DelayTimer -> DelayTimer;

}
