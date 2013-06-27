configuration RebootCounterC{
  provides interface Get<uint16_t>;
} implementation {
  components MainC;
  components SettingsStorageC;
  components RebootCounterP;

  MainC.SoftwareInit -> RebootCounterP;
  RebootCounterP.SettingsStorage -> SettingsStorageC;

  Get = RebootCounterP;
}
