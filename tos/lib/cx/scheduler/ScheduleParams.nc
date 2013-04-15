
 #include "CXScheduler.h"
interface ScheduleParams{
  command void setSchedule(cx_schedule_t* schedule);

  command void setCycleStart(uint32_t cycleStart);

  command void setSlot(uint32_t slot);

  command void setMasterId(am_addr_t addr);
}

