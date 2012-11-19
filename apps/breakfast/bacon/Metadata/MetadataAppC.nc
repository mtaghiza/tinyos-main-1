 #include "ctrl_messages.h"
configuration MetadataAppC{
} implementation {
  components MainC;
  components MetadataP;
  components UtilitiesC;
  components BusC;
  components ToastTLVC;
  components BaconTLVC;

  components new TimerMilliC();

  components PrintfC;
  components SerialStartC;
  
  components SerialActiveMessageC;

  MetadataP.Boot -> MainC;

  MetadataP.Packet -> SerialActiveMessageC;
  MetadataP.SerialSplitControl -> SerialActiveMessageC;

  components new PoolC(message_t, 16);
  MetadataP.Pool -> PoolC;
  UtilitiesC.Pool -> PoolC;
  BusC.Pool -> PoolC;
  ToastTLVC.Pool -> PoolC;
  BaconTLVC.Pool -> PoolC;

  ToastTLVC.LastSlave -> BusC.Get;

  components LedsC;
  MetadataP.Leds -> LedsC;


  //Receive
  components new SerialAMReceiverC(AM_READ_IV_CMD_MSG) as ReadIvCmdReceive;
  MetadataP.ReadIvCmdReceive -> ReadIvCmdReceive;
  components new SerialAMReceiverC(AM_READ_MFR_ID_CMD_MSG) as ReadMfrIdCmdReceive;
  MetadataP.ReadMfrIdCmdReceive -> ReadMfrIdCmdReceive;
  components new SerialAMReceiverC(AM_RESET_BACON_CMD_MSG) as ResetBaconCmdReceive;
  MetadataP.ResetBaconCmdReceive -> ResetBaconCmdReceive;
  //Send
  components new SerialAMSenderC(AM_READ_IV_RESPONSE_MSG) as ReadIvResponseSend;
  MetadataP.ReadIvResponseSend -> ReadIvResponseSend;
  components new SerialAMSenderC(AM_READ_MFR_ID_RESPONSE_MSG) as ReadMfrIdResponseSend;
  MetadataP.ReadMfrIdResponseSend -> ReadMfrIdResponseSend;
  components new SerialAMSenderC(AM_RESET_BACON_RESPONSE_MSG) as ResetBaconResponseSend;
  MetadataP.ResetBaconResponseSend -> ResetBaconResponseSend;
  
}
