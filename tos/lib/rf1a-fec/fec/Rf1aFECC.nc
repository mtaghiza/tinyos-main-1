generic configuration Rf1aFECC () {
  provides interface Rf1aPhysical[uint8_t client];
  provides interface Rf1aPhysicalMetadata;

  uses interface Rf1aPhysical as SubRf1aPhysical[uint8_t client];
  uses interface Rf1aPhysicalMetadata as SubRf1aPhysicalMetadata;
} implementation {
  components new Rf1aFECP();
  components CC430CRCC;

  //TODO: switch between encodings
  components DummyFECC as FEC;

  Rf1aFECP.FEC -> FEC;

  Rf1aFECP.Crc -> CC430CRCC;
  Rf1aFECP.SubRf1aPhysical = SubRf1aPhysical;
  Rf1aPhysical = Rf1aFECP.Rf1aPhysical;
  Rf1aPhysicalMetadata = Rf1aFECP.Rf1aPhysicalMetadata;
  Rf1aFECP.SubRf1aPhysicalMetadata = SubRf1aPhysicalMetadata;
}
