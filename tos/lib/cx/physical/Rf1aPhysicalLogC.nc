generic configuration Rf1aPhysicalLogC (){
  provides interface Rf1aPhysical;

  provides interface DelayedSend;
  provides interface RadioStateLog;

  provides interface Rf1aPhysicalMetadata;
  uses interface Rf1aTransmitFragment;
  uses interface Rf1aConfigure;
  provides interface Resource;
  provides interface Rf1aStatus;
} implementation {
  components Rf1aPhysicalLogP;
  components new Rf1aPhysicalC();

  Rf1aPhysical = Rf1aPhysicalLogP.Rf1aPhysical;
  Rf1aPhysicalLogP.SubRf1aPhysical -> Rf1aPhysicalC;

//  DelayedSend = Rf1aPhysicalC;
  DelayedSend = Rf1aPhysicalLogP.DelayedSend;
  Rf1aPhysicalLogP.SubDelayedSend -> Rf1aPhysicalC.DelayedSend;

  RadioStateLog = Rf1aPhysicalLogP;
  components LocalTime32khzC;
  Rf1aPhysicalLogP.LocalTime -> LocalTime32khzC;
  
  Rf1aPhysicalMetadata = Rf1aPhysicalC;
  Rf1aTransmitFragment = Rf1aPhysicalC;
  Rf1aConfigure = Rf1aPhysicalC;
  Resource = Rf1aPhysicalC;
  Rf1aStatus = Rf1aPhysicalC;

}
