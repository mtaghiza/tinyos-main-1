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
  
  components ActiveMessageC;

  MetadataP.Boot -> MainC;

  MetadataP.Packet -> ActiveMessageC;
  MetadataP.AMPacket -> ActiveMessageC;
  MetadataP.SerialSplitControl -> ActiveMessageC;

  components new PoolC(message_t, 8);
  MetadataP.Pool -> PoolC;
  UtilitiesC.Pool -> PoolC;
  BusC.Pool -> PoolC;
  ToastTLVC.Pool -> PoolC;
  BaconTLVC.Pool -> PoolC;

  ToastTLVC.LastSlave -> BusC.Get;

  components LedsC;
  MetadataP.Leds -> LedsC;


  //Receive
  components new AMReceiverC(AM_READ_IV_CMD_MSG) as ReadIvCmdReceive;
  MetadataP.ReadIvCmdReceive -> ReadIvCmdReceive;
  components new AMReceiverC(AM_READ_MFR_ID_CMD_MSG) as ReadMfrIdCmdReceive;
  MetadataP.ReadMfrIdCmdReceive -> ReadMfrIdCmdReceive;
  components new AMReceiverC(AM_RESET_BACON_CMD_MSG) as ResetBaconCmdReceive;
  MetadataP.ResetBaconCmdReceive -> ResetBaconCmdReceive;
  //Send
  components new AMSenderC(AM_READ_IV_RESPONSE_MSG) as ReadIvResponseSend;
  MetadataP.ReadIvResponseSend -> ReadIvResponseSend;
  components new AMSenderC(AM_READ_MFR_ID_RESPONSE_MSG) as ReadMfrIdResponseSend;
  MetadataP.ReadMfrIdResponseSend -> ReadMfrIdResponseSend;
  components new AMSenderC(AM_RESET_BACON_RESPONSE_MSG) as ResetBaconResponseSend;
  MetadataP.ResetBaconResponseSend -> ResetBaconResponseSend;
  
}
