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

configuration CXPacketStackC{
  provides interface CXPacket;
  provides interface CXPacketMetadata;
  provides interface AMPacket;
  provides interface Ieee154Packet;

  //required at interface with HPL
  provides interface Packet as Ieee154PacketBody;
  provides interface Packet as CXPacketBody;
  provides interface Packet as AMPacketBody;

  provides interface Rf1aPacket;
  provides interface PacketAcknowledgements;

} implementation {
  components CXTDMAPhysicalC;

  components new Rf1aIeee154PacketC() as Ieee154PacketC; 
  Ieee154PacketC.Rf1aPhysicalMetadata -> CXTDMAPhysicalC;
  components Ieee154AMAddressC;

  Ieee154Packet = Ieee154PacketC.Ieee154Packet;
  Ieee154PacketBody = Ieee154PacketC.Packet;
  Rf1aPacket = Ieee154PacketC.Rf1aPacket;


  components Rf1aCXPacketC;
  Rf1aCXPacketC.SubPacket -> Ieee154PacketC;
  Rf1aCXPacketC.Ieee154Packet -> Ieee154PacketC;
  Rf1aCXPacketC.Rf1aPacket -> Ieee154PacketC;
  Rf1aCXPacketC.ActiveMessageAddress -> Ieee154AMAddressC;

  components Rf1aAMPacketC as AMPacketC;
  AMPacketC.SubPacket -> Rf1aCXPacketC;
  AMPacketC.Ieee154Packet -> Ieee154PacketC;
  AMPacketC.Rf1aPacket -> Ieee154PacketC;
  AMPacketC.ActiveMessageAddress -> Ieee154AMAddressC;
  Rf1aCXPacketC.AMPacket -> AMPacketC;
  AMPacketBody = AMPacketC;

  CXPacketBody = Rf1aCXPacketC.Packet;
  CXPacket = Rf1aCXPacketC.CXPacket;
  CXPacketMetadata = Rf1aCXPacketC.CXPacketMetadata;
  AMPacket = AMPacketC;
  PacketAcknowledgements = Rf1aCXPacketC.PacketAcknowledgements;

}
