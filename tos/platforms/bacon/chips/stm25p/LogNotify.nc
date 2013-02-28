interface LogNotify{
  command error_t setHighThreshold(uint16_t thresh);
  command error_t setLowThreshold(uint16_t thresh);
  command error_t reportSent(uint16_t sent);
  command void forceFlushed();
  //maybe return bool indicating whether or not we're going to handle
  //it immediately?
  event void sendRequested(uint16_t left);
}
