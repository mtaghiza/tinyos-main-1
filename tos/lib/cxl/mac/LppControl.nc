interface LppControl {
  command error_t wakeup(uint8_t ns);
  command error_t sleep();
  command error_t setProbeInterval(uint32_t t);

  event void wokenUp(uint8_t ns);
  event void fellAsleep();
  command bool isAwake();
}
