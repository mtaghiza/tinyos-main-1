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


#ifndef USE_AM_RADIO
#define USE_AM_RADIO 0
#endif

configuration MDActiveMessageC{
  provides interface SplitControl;
  provides interface AMSend[am_id_t id];
  provides interface Receive[am_id_t id];
  
  #if USE_AM_RADIO == 1
  provides interface Receive as Snoop[am_id_t id];
  provides interface LowPowerListening;
  #endif

  provides interface Packet;
  provides interface AMPacket;
  provides interface PacketAcknowledgements;
} implementation {
  #if USE_AM_RADIO == 1
  components ActiveMessageC as AM;
  Snoop        = AM.Snoop;
  LowPowerListening = AM;
  #else 
  components SerialActiveMessageC as AM;
  #endif

  SplitControl = AM;
  AMSend       = AM;
  Receive      = AM.Receive;
  Packet       = AM;
  AMPacket     = AM;
  PacketAcknowledgements = AM;
}
