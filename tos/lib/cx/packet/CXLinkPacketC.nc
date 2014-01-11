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

configuration CXLinkPacketC{
  provides interface CXLinkPacket;
  provides interface Rf1aPacket;
  provides interface Packet;
  provides interface Ieee154Packet;

  uses interface Rf1aPhysicalMetadata;

} implementation {
  //The link layer does not add anything to the packet, it just reuses
  //elements of the 15.4 header.
  components new Rf1aIeee154PacketC();
  Rf1aPacket = Rf1aIeee154PacketC;

  components CXPacketMetadataC;

  components CXLinkPacketP;
  CXLinkPacketP.Ieee154Packet -> Rf1aIeee154PacketC;
  CXLinkPacketP.Rf1aPacket -> Rf1aIeee154PacketC;
  Packet = CXLinkPacketP.Packet;
  CXLinkPacketP.SubPacket -> Rf1aIeee154PacketC;
  CXLinkPacketP.CXPacketMetadata -> CXPacketMetadataC;

  CXLinkPacket = CXLinkPacketP;
  Rf1aIeee154PacketC.Rf1aPhysicalMetadata = Rf1aPhysicalMetadata;
  Ieee154Packet = Rf1aIeee154PacketC;
}
