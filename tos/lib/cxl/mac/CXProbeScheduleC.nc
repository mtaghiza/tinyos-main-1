
 #include "CXMac.h"
configuration CXProbeScheduleC {
  provides interface Get<probe_schedule_t*>;
} implementation {
  components CXProbeScheduleP;
  Get = CXProbeScheduleP;
  
  components MainC;
  MainC.SoftwareInit -> CXProbeScheduleP.Init;
  components SettingsStorageC;
  CXProbeScheduleP.SettingsStorage -> SettingsStorageC;

}
