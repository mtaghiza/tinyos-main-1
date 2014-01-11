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

module CXBasestationP {
} implementation {
  //wakeup schedule:
  // slotLength = tone + 1 packet
  // to guarantee waking up all nodes at depth i or lower:
  //   activeSlots = numSlots = search_numSlots*i
  cx_schedule_t wakeupSchedule = {
    .slotLength = 2 + SEARCH_MAXDEPTH,
    .activeSlots = SEARCH_NUMSLOTS,
    .numSlots = SEARCH_NUMSLOTS,
    .beaconInterval = 1,
    .beaconOffset = 0,
  };

  //"normal" schedule:
  // activeSlots = dictated by network size
  // slotLength = tone + several packets, at least.
  // numSlots = f(slotLength, ipi)
  cx_schedule_t activeSchedule = {
    .slotLength  =  DEFAULT_SLOTLENGTH,
    .activeSlots =  DEFAULT_ACTIVESLOTS,
    .numSlots    =  DEFAULT_NUMSLOTS,
    .beaconInterval = CX_BEACON_INTERVAL,
    .beaconOffset = 1
  };

  cx_schedule_t* sched = &wakeupSchedule;


  command error_t RoleScheduler.setCycle(uint32_t t0, 
      uint16_t uplinkActive, uint16_t downlinkActive, 
      uint16_t cycleLen){
    //TODO: set activeSchedule contents from params
    call ActivityScheduler.setSlotStart(0, t0, 0);
  }

  event error_t CXActivityScheduler.slotStarted(uint16_t slotNumber,
      cx_slot_rules_t* rules){
    //send out the master network schedule.
    if ((slotNumber - sched->beaconOffset)% sched->beaconInterval == 0){
      setSlotNumber(schedMsg, slotNumber);
      call SubSend.send(schedMsg, sizeof(cx_schedule_t));
      rules -> active = TRUE;
      rules -> txTone = CX_BEACON_CHANNEL;
    }else{
      if (active){
        //TODO: check what tier this slot is in and whether it's active.
        if (shouldAnnounce(slotNumber)){
          //TODO: get a message out of the pool
          //TODO: set slot number
          //TODO: configure as offer
          //TODO: send it
        }
      }
    } 
  }

  event void SubSend.sendDone(message_t* msg, error_t error){
    if (isOffer(msg)){
      //TODO: put back into pool
    } else if(isAssignment(msg)){
      //pass
    } else if(isSchedule(msg)){
      //pass: keep this pointer.
    }else{
      signal Send.sendDone(msg, error);
    }
  }

  bool shouldAnnounce(uint16_t slotNumber){
    //TODO: look in schedule: we should have a small number of slots
    //up for grabs at any time, and clear them out as they're claimed.
    return TRUE;
  }

  command error_t Send.send(message_t* msg, error_t error){
    //TODO: set slot number to owned slot, set TTL if not already set.
    return call SubSend.send(msg, error);
  }
}
