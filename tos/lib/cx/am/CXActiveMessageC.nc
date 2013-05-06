/* Copyright (c) 2010 People Power Co.
 * All rights reserved.
 *
 * This open source code was developed with funding from People Power Company
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
 * - Neither the name of the People Power Corporation nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE
 * PEOPLE POWER CO. OR ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE
 *
 */

/** TinyOS network stack for ActiveMessage communication on an RF1A radio.
 *
 * This is a demonstration stack; applications may choose to use
 * another with additional features such as low-power listening.
 *
 * Stack structure:
 * - ActiveMessage support
 * - TinyOS/Physical bridge
 * - Rf1a physical layer
 *
 * @author Peter A. Bigot <pab@peoplepowerco.com> */

configuration CXActiveMessageC {
  provides interface SplitControl;
  provides interface AMSend[am_id_t id];
  provides interface Receive[am_id_t id];
  provides interface Receive as Snoop[am_id_t id];
  provides interface Packet;
  provides interface AMPacket;
  provides interface PacketAcknowledgements as Acks;
}
implementation {

  components Rf1aAMPacketC as PacketC;
  components CXTransportPacketC;
  components CXLinkPacketC;
  components CXPacketMetadataC;

  Packet = PacketC;
  AMPacket = PacketC;

  PacketC.SubPacket -> CXTransportPacketC;
  PacketC.Rf1aPacket -> CXLinkPacketC;
  PacketC.Ieee154Packet ->CXLinkPacketC;

  /* Get support for identifying the node's address.  Implementation
   * derives from underlying 802.15.4 address (eventually). */
  components CXAMAddressC;
  PacketC.ActiveMessageAddress -> CXAMAddressC;

  components CXActiveMessageP as AM;
  AMSend = AM;
  Receive = AM.Receive;
  Snoop = AM.Snoop;
  Acks = AM.Acks;
  AM.Rf1aPacket -> CXLinkPacketC;
  AM.Ieee154Packet -> CXLinkPacketC;
  AM.Packet -> PacketC;
  AM.AMPacket -> PacketC;
  AM.CXPacketMetadata -> CXPacketMetadataC;

  components CXTransportC;
  AM.BroadcastSend -> CXTransportC.BroadcastSend;
  AM.BroadcastReceive -> CXTransportC.BroadcastReceive;
  AM.UnicastSend -> CXTransportC.UnicastSend;
  AM.UnicastReceive -> CXTransportC.UnicastReceive;
  AM.ScheduledSend -> CXTransportC.ScheduledSend;
  SplitControl = CXTransportC.SplitControl;
}

/* 
 * Local Variables:
 * mode: c
 * End:
 */
