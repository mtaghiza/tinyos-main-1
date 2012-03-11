generic configuration Rf1aTDMAC() {
  provides interface SplitControl;
  provides interface CXTDMA;
  provides interface Receive;

  uses interface Rf1aPhysical;
  uses interface Resource;
} implementation{
  components new Rf1aTDMAP();

  SplitControl = Rf1aTDMAP;
  CXTDMA = Rf1aTDMAP;
  Receive = Rf1aTDMAP;
  Rf1aPhysical = Rf1aTDMAP;
  Resource = Rf1aTDMAP;
}
