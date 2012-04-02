interface SWCapture {
  //set to active state
  async command error_t active();
  //set to inactive state
  async command error_t inactive();
  //return the total number of ticks spent in active up until this
  //point
  async command uint32_t getActive();
}
