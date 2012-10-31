 #include "ctrl_messages.h"
configuration MetadataAppC{
} implementation {
  components MainC;
  components MetadataP;
  components new TimerMilliC();

  components PrintfC;
  components SerialStartC;
  
  components new SerialAMSenderC(AM_TEST_MSG) as TestSend;
  components SerialActiveMessageC;

  MetadataP.Boot -> MainC;
  MetadataP.Timer -> TimerMilliC;

  MetadataP.TestSend -> TestSend;
  MetadataP.Packet -> TestSend;
  MetadataP.SerialSplitControl -> SerialActiveMessageC;

}
