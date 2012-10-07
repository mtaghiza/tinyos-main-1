generic configuration Rf1aFECC () {
  provides interface Rf1aPhysical[uint8_t client];
  uses interface Rf1aPhysical as SubRf1aPhysical[uint8_t client];
} implementation {
  components new Rf1aFECP();

  Rf1aFECP.SubRf1aPhysical = SubRf1aPhysical;
  Rf1aPhysical = Rf1aFECP.Rf1aPhysical;
}
