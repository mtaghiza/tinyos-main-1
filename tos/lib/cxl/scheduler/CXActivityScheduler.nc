/*
 * Copyright (c) 2014 Johns Hopkins University.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
*/

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
