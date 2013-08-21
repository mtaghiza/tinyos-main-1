
 #include "CXMac.h"
configuration CXProbeScheduleC {
  provides interface Get<probe_schedule_t*>;
} implementation {
  #ifndef ENABLE_PROBE_SCHEDULE_CONFIG
  #define ENABLE_PROBE_SCHEDULE_CONFIG 1
  #endif

  #if ENABLE_PROBE_SCHEDULE_CONFIG == 1
  components CXProbeScheduleP;
  #else
  #warning Disable configurable probe schedule
  components CXProbeScheduleStaticP as CXProbeScheduleP;
  #endif

  Get = CXProbeScheduleP;
  
  components MainC;
  MainC.SoftwareInit -> CXProbeScheduleP.Init;
  components SettingsStorageC;
  CXProbeScheduleP.SettingsStorage -> SettingsStorageC;

}
