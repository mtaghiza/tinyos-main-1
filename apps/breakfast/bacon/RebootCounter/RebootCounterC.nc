configuration RebootCounterC{
} implementation {
  components MainC;
  components SettingsStorageC;
  components RebootCounterP;

  MainC.SoftwareInit -> RebootCounterP;
  RebootCounterP.SettingsStorage -> SettingsStorageC;
}
