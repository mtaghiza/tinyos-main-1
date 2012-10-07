generic configuration HplMsp430Rf1aFECP() {
  provides {
    interface ResourceConfigure[uint8_t client];
    interface Rf1aPhysical[uint8_t client];
    interface Rf1aStatus;
    interface Rf1aPhysicalMetadata;
  }
  uses {
    interface ArbiterInfo;
    interface HplMsp430Rf1aIf as Rf1aIf;
    interface Rf1aConfigure[uint8_t client];
    interface Rf1aTransmitFragment[uint8_t client];
    interface Rf1aInterrupts[uint8_t client];
    interface Leds;
  }
} implementation {
  components new Rf1aFECC();
  
  components new HplMsp430Rf1aP() as HplRf1aP;
  HplRf1aP.Rf1aIf = Rf1aIf;
  HplRf1aP.ArbiterInfo = ArbiterInfo;
  Rf1aPhysicalMetadata = HplRf1aP;
  Rf1aTransmitFragment = HplRf1aP;
  Rf1aStatus = HplRf1aP;
  Rf1aConfigure = HplRf1aP;
  ResourceConfigure = HplRf1aP;

  HplRf1aP.Rf1aInterrupts = Rf1aInterrupts;
  HplRf1aP.Leds = Leds;

  Rf1aPhysical = Rf1aFECC;
  Rf1aFECC.SubRf1aPhysical -> HplRf1aP;

}
