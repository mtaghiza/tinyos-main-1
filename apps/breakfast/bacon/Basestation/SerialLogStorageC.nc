
 #include "RecordStorage.h"
generic configuration SerialLogStorageC() {
  provides interface LogWrite;
  uses interface Pool<message_t>;
} implementation {
  components new SerialAMSenderC(AM_LOG_RECORD_DATA_MSG);
  
  components new SerialLogStorageP();
  LogWrite = SerialLogStorageP.LogWrite;
  SerialLogStorageP.AMSend -> SerialAMSenderC;
  SerialLogStorageP.Pool = Pool;
  SerialLogStorageP.Packet -> SerialAMSenderC;
  SerialLogStorageP.AMPacket -> SerialAMSenderC;


  components CXAMAddressC;
  SerialLogStorageP.ActiveMessageAddress -> CXAMAddressC;

  components SettingsStorageC;
  SerialLogStorageP.SettingsStorage -> SettingsStorageC;
}
