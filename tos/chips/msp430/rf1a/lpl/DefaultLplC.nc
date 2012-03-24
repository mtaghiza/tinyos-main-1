/*
 * Copyright (c) 2005-2006 Rincon Research Corporation
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the Rincon Research Corporation nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE
 * RINCON RESEARCH OR ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE
 */

/**
 * Low Power Listening for the CC2420
 * @author David Moss
 */


#include "DefaultLpl.h"
#warning "*** USING DEFAULT LOW POWER COMMUNICATIONS ***"

configuration DefaultLplC {
  provides {
    interface LowPowerListening;
    interface Send;
    interface Receive;
    interface SplitControl;
    interface State as SendState;
  }
  
  uses { 
    interface Send as SubSend;
    interface Receive as SubReceive;
    interface SplitControl as SubControl;
    interface PacketAcknowledgements;
    interface Rf1aPhysical;
  }
}

implementation {
  components DefaultLplP;
  LowPowerListening = DefaultLplP;
  Send = DefaultLplP;
  Receive = DefaultLplP;
  SubControl = DefaultLplP.SubControl;
  SubControl = PowerCycleC.SubControl;
  SubReceive = DefaultLplP.SubReceive;
  SubSend = DefaultLplP.SubSend;
  PacketAcknowledgements = DefaultLplP.PacketAcknowledgements;
  
  components MainC;
  MainC.SoftwareInit -> DefaultLplP;
  
  components new Rf1aIeee154PacketC();
  DefaultLplP.Ieee154Packet -> Rf1aIeee154PacketC;  
  DefaultLplP.Rf1aPacket -> Rf1aIeee154PacketC;  
    
  components PowerCycleC;
  SplitControl = PowerCycleC;
  DefaultLplP.SplitControlState -> PowerCycleC.SplitControlState;
  DefaultLplP.RadioPowerState -> PowerCycleC.RadioPowerState;
  DefaultLplP.PowerCycle -> PowerCycleC;
  Rf1aPhysical = PowerCycleC;
  Rf1aPhysical = DefaultLplP;

  components new StateC() as SendStateC;
  SendState = SendStateC;
  DefaultLplP.SendState -> SendStateC;

  components new TimerMilliC() as OffTimerC;
  DefaultLplP.OffTimer -> OffTimerC;

  components new TimerMilliC() as SendDoneTimerC;
  DefaultLplP.SendDoneTimer -> SendDoneTimerC;

  components RandomC;
  DefaultLplP.Random -> RandomC;

  components LedsC;
  DefaultLplP.Leds -> LedsC;

  components SystemLowPowerListeningC;
  DefaultLplP.SystemLowPowerListening -> SystemLowPowerListeningC;
}
