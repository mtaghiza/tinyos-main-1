
 #include "CXMac.h"
configuration CXProbeScheduleC {
  provides interface Get<probe_schedule_t*>;
} implementation {
  components CXProbeScheduleP;
  Get = CXProbeScheduleP;

  components SettingsStorageC;
  CXProbeScheduleP.SettingsStorage -> SettingsStorageC;

}
