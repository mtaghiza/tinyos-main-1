interface ScheduledSend{
  command uint16_t getSlot();
  command bool sendReady();
}
