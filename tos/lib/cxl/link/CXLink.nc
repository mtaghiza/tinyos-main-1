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

 
 #include "CXLink.h"
/**
 * This interface provides high-level access to the
 * physical radio layer. The implementer is responsible for
 * coordinating event timings with the precision necessary for
 * non-destructive concurrent transmsisions.
 * 
 * Generally speaking, users of this interface will 
 * - use rxTone with a relatively long timeout to synchronize with the
 *   network.
 * - use rxTone with a short timeout to detect upcoming channel usage,
 *   followed by either a sleep or a series of short-timeout RX's to
 *   receive/forward data.
 * - use txTone periodically to synchronize the network and indicate
 *   upcoming channel usage.
 * - sleep the radio when no activity is present.
 */
interface CXLink {
  /**
   * Immediately sleep the radio if not in the middle of a sensitive
   * operation. Return SUCCESS if radio is sleep'ed, FAIL if it
   * couldn't be sleep'ed immediately.
   */
  command error_t sleep();

  /**
   * Put the radio into RX mode and wait [timeout] for a packet to
   * arrive. If a packet is received, it is forwarded at FRAMELEN_FAST
   * intervals from its original reception (decrementing TTL each
   * time) until its TTL reaches 0. 
   * If allowRetx is false, this will immediately signal a received
   * packet up the stack and will not forward it.
   * 
   * Returns SUCCESS if an rxDone will eventually be signalled.
   */
  command error_t rx(uint32_t timeout, bool allowRetx);
  /**
   * Indicate that an rx has completed (either due to timeout or due
   * to a reception/forwarding). This will not signal up until the
   * forwarding process is done, in the event of reception. The
   * implementor's Receive interface will get signalled before the
   * CXLink's rxDone event gets signalled.
   */
  event void rxDone();
  
  /**
   * Pass through to Rf1aPhysical's setChannel command (after checking
   * state safety)
   */
  command error_t setChannel(uint8_t channel);

  command cx_link_stats_t getStats();

//Obsoleted: link layer uses shorter forward times for packets with 1
//byte (e.g. MAC layer control packets). This lets us get most of the
//benefit of wakeup tones with a lot more code reuse
//  /**
//   * Listen for an extended wakeup tone on a given channel (and leave
//   * the radio tuned to that channel at its completion). If a tone is
//   * detected, this node will attempt to join in its transmission.
//   * 
//   * Returns SUCCESS if a toneReceived will eventually be signalled.
//   */
//  command error_t rxTone(uint32_t timeout, uint8_t channel);
//  /**
//   *  signal the completion of an rxTone command, either due to
//   *  timeout or reception of a tone. This will not signal up until
//   *  the forwarding of the tone is complete.
//   *  "received" is true if a tone was detected, false if not.
//   *  The radio is left to the channel specified in the original
//   *  rxTone call.
//   */
//  event void toneReceived(bool received);
//  
//  /** 
//   * Send an extended wakeup tone on a given channel, and leave the
//   * radio tuned to that channel.
//   * 
//   * Returns SUCCESS if a toneSent event will eventually be signalled.
//   */
//  command error_t txTone(uint8_t channel);
//  /**
//   * Indicates the completion of a txTone command.
//   */
//  event void toneSent();
}
