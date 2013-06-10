interface CXActivityScheduler {
  /**
   *  Peg a slot number to a given point in time (32k ticks).
   *  The next slotStarted event should be signalled with a slotNumber
   *  consistent with this command and at a time consistent with
   *  t0/dt.
   */
  command error_t setSlotStart(uint16_t atSlotNumber, 
    uint32_t t0, uint32_t dt);
  
  /**
   *  Signal the start of a slot up the stack. rules is used as a
   *  tuple return vessel. 
   * 
   *  If the handler returns SUCCESS, the implementer of this
   *  interface will change channel/ set timeouts based on the rules
   *  pointer's contents. Otherwise, the implementer will sleep.
   */
  event error_t slotStarted(uint16_t slotNumber, cx_slot_rules_t* rules);

  /**
   *  Turn the radio off until the next slot start. Timing information
   *  is preserved.
   */
  command error_t CXActivityScheduler.sleep();

  /**
   *  Turn the radio off and stop slot-cycling.
   */
  command error_t CXActivityScheduler.stop();
}
