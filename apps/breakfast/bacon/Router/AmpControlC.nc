configuration AmpControlC{
  provides interface Rf1aPhysical;
  uses interface Rf1aPhysical as SubRf1aPhysical;
} implementation {
  components AmpControlP;
  components MainC;
  MainC.SoftwareInit -> AmpControlP;
  Rf1aPhysical = SubRf1aPhysical;

  components CC1190PinsC;
  AmpControlP.HGMPin -> CC1190PinsC.HGMPin;
  AmpControlP.LNA_ENPin -> CC1190PinsC.LNA_ENPin;
  AmpControlP.PA_ENPin -> CC1190PinsC.PA_ENPin;
  AmpControlP.PowerPin -> CC1190PinsC.PowerPin;
}
