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


 #include "CXNetwork.h"
configuration CXNetworkC {
  provides interface SplitControl;
  provides interface CXRequestQueue;
  provides interface Packet;
  provides interface CXNetworkPacket;
  provides interface Notify<uint32_t> as ActivityNotify;

} implementation {
  components CXNetworkP;

  components CXNetworkPacketC;
  components CXPacketMetadataC;

  //convenience interfaces
  Packet = CXNetworkPacketC;
  CXNetworkPacket = CXNetworkPacketC;

  components CXLinkC;
  
  SplitControl = CXLinkC;
  ActivityNotify = CXNetworkP.ActivityNotify;

  CXRequestQueue = CXNetworkP;
  CXNetworkP.SubCXRequestQueue -> CXLinkC;

  CXNetworkP.CXLinkPacket -> CXLinkC;

  CXNetworkP.CXNetworkPacket -> CXNetworkPacketC;

  CXNetworkP.CXPacketMetadata -> CXPacketMetadataC;

  components ActiveMessageC;
  CXNetworkP.AMPacket -> ActiveMessageC;

  components new PoolC(cx_network_metadata_t, CX_NETWORK_POOL_SIZE);
  CXNetworkP.Pool -> PoolC;

  components CXRoutingTableC;
  CXNetworkP.RoutingTable -> CXRoutingTableC;
  
  components CXAMAddressC;
  CXNetworkP.ActiveMessageAddress -> CXAMAddressC;
 
  //For debug
  components CXTransportPacketC;
  components LocalTime32khzC;
  components CXLinkPacketC;
  CXNetworkP.CXTransportPacket -> CXTransportPacketC;
  CXNetworkP.LocalTime -> LocalTime32khzC;
  CXNetworkP.Rf1aPacket -> CXLinkPacketC;

}
