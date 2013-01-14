generic configuration HplMsp430Rf1aFECP() {
  provides interface ResourceConfigure[uint8_t client];
  provides interface Rf1aPhysical[uint8_t client];
  provides interface Rf1aStatus;
  provides interface Rf1aPhysicalMetadata;
  provides interface DelayedSend[uint8_t client];

  
  uses interface ArbiterInfo;
  uses interface HplMsp430Rf1aIf as Rf1aIf;
  uses interface Rf1aConfigure[uint8_t client];
  uses interface Rf1aTransmitFragment[uint8_t client];
  uses interface Rf1aInterrupts[uint8_t client];
  uses interface Leds;
} implementation {
  components new Rf1aFECC();
  
  components new HplMsp430Rf1aP() as HplRf1aP;
  HplRf1aP.Rf1aIf = Rf1aIf;
  HplRf1aP.ArbiterInfo = ArbiterInfo;
  Rf1aPhysicalMetadata = HplRf1aP;
  Rf1aStatus = HplRf1aP;
  Rf1aConfigure = HplRf1aP;
  ResourceConfigure = HplRf1aP;

  HplRf1aP.Rf1aInterrupts = Rf1aInterrupts;
  HplRf1aP.Leds = Leds;

  Rf1aPhysical = Rf1aFECC;
  Rf1aFECC.SubRf1aPhysical -> HplRf1aP;
  HplRf1aP.Rf1aTransmitFragment -> Rf1aFECC.SubRf1aTransmitFragment;

  Rf1aTransmitFragment = Rf1aFECC.Rf1aTransmitFragment;
  DelayedSend = HplRf1aP.DelayedSend;
}
