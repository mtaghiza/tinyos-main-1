interface LppControl {
  command error_t wakeup();
  command error_t sleep();
  command error_t setProbeInterval(uint32_t t);
}
