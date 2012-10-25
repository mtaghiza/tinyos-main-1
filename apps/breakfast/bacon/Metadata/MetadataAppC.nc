configuration MetadataAppC{
} implementation {
  components MainC;
  components MetadataP;
  components new TimerMilliC();

  components PrintfC;
  components SerialStartC;
  
  MetadataP.Boot -> MainC;
  MetadataP.Timer -> TimerMilliC;
}
