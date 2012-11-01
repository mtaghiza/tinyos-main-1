 #include "ctrl_messages.h"
configuration MetadataAppC{
} implementation {
  components MainC;
  components MetadataP;
  components new TimerMilliC();

  components PrintfC;
  components SerialStartC;
  
  components SerialActiveMessageC;

  MetadataP.Boot -> MainC;
  MetadataP.Timer -> TimerMilliC;

  MetadataP.Packet -> SerialActiveMessageC;
  MetadataP.SerialSplitControl -> SerialActiveMessageC;

}
