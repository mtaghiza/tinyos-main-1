configuration AmpControlC{
  provides interface Rf1aPhysical;
  uses interface Rf1aPhysical as SubRf1aPhysical;
} implementation {
  Rf1aPhysical = SubRf1aPhysical;
}
