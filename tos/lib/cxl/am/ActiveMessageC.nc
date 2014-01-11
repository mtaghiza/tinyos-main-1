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


  #ifndef HAS_ACTIVE_MESSAGE
  #define HAS_ACTIVE_MESSAGE
  #endif
configuration ActiveMessageC{
  provides interface SplitControl;
  provides interface AMSend[uint8_t ns];
  provides interface Receive[am_id_t id];
  provides interface Receive as Snoop[am_id_t id];

  provides interface Packet;
  provides interface AMPacket;
  provides interface PacketAcknowledgements as Acks;

  provides interface Pool<message_t>;
  provides interface CTS[uint8_t segment];

} implementation {
  components CXActiveMessageC as AM;

  SplitControl = AM.SplitControl;
  AMSend = AM.AMSend;
  Receive = AM.Receive;
  Snoop = AM.Snoop;
  Packet = AM.Packet;
  AMPacket = AM.AMPacket;
  Acks = AM.Acks;
  CTS = AM.CTS;
  
  #ifndef AM_POOL_SIZE 
  #define AM_POOL_SIZE 4
  #endif
  components new PoolC(message_t, AM_POOL_SIZE);
  AM.Pool -> PoolC;
  Pool = PoolC;
}
