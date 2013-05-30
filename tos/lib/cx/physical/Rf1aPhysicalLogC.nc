generic configuration Rf1aPhysicalLogC (){
  provides interface Rf1aPhysical;
  uses interface Rf1aPhysical as SubRf1aPhysical;

  provides interface DelayedSend;
  uses interface DelayedSend as SubDelayedSend;
  provides interface RadioStateLog;

  provides interface Rf1aPhysicalMetadata;
  uses interface Rf1aPhysicalMetadata as SubRf1aPhysicalMetadata;

  uses interface Rf1aTransmitFragment;
  provides interface Rf1aTransmitFragment as SubRf1aTransmitFragment;

  uses interface Rf1aConfigure;
  provides interface Rf1aConfigure as SubRf1aConfigure;

  provides interface Resource;
  uses interface Resource as SubResource;

  provides interface Rf1aStatus;
  uses interface Rf1aStatus as SubRf1aStatus;
} implementation {
  components Rf1aPhysicalLogP;

  Rf1aPhysical = Rf1aPhysicalLogP.Rf1aPhysical;
  Rf1aPhysicalLogP.SubRf1aPhysical = SubRf1aPhysical;

  DelayedSend = Rf1aPhysicalLogP.DelayedSend;
  Rf1aPhysicalLogP.SubDelayedSend = SubDelayedSend;

  RadioStateLog = Rf1aPhysicalLogP;
  components LocalTime32khzC;
  Rf1aPhysicalLogP.LocalTime -> LocalTime32khzC;
  
  Rf1aPhysicalMetadata = SubRf1aPhysicalMetadata;
  Rf1aTransmitFragment = SubRf1aTransmitFragment;
  Rf1aConfigure = SubRf1aConfigure;
  Resource = SubResource;
  Rf1aStatus = SubRf1aStatus;
}
