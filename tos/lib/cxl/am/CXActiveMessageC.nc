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

#include "multiNetwork.h"
configuration CXActiveMessageC {
  provides interface SplitControl;
  provides interface AMSend[uint8_t ns];
  provides interface Receive[am_id_t id];
  provides interface Receive as Snoop[am_id_t id];
  provides interface Packet;
  provides interface AMPacket;
  provides interface PacketAcknowledgements as Acks;
  
  provides interface CTS[uint8_t segment];

  uses interface Pool<message_t>;
}
implementation {

  components CXAMPacketC as PacketC;
  components CXMacPacketC;
  components CXLinkPacketC;

  Packet = PacketC;
  AMPacket = PacketC;

  PacketC.SubPacket -> CXMacPacketC;
  PacketC.CXLinkPacket -> CXLinkPacketC;

  components CXAMAddressC;
  PacketC.ActiveMessageAddress -> CXAMAddressC;

  components CXActiveMessageP as AM;
  AMSend = AM;
  Receive = AM.Receive;
  Snoop = AM.Snoop;
  Acks = AM.Acks;

  AM.Packet -> PacketC;
  AM.AMPacket -> PacketC;

  #ifndef CX_LPP_BASIC
  #define CX_LPP_BASIC 0
  #endif
  
  #if CX_LPP_BASIC == 1
  #warning "Using basic (non-dc'ed) LPP"
  components CXMacC as Mac;
  #else
  #warning "Using dc'ed LPP"
    
    //TODO: these should expand to cover all of the relevant network
    //segments for the role.
    #if CX_ROUTER == 1
    components CXRouterC as Mac;
    CTS[NS_SUBNETWORK] = Mac.CTS;
    #else
    components CXLeafC as Mac;
    CTS[NS_SUBNETWORK] = Mac.CTS;
    #endif
  #endif
 
  AM.SubSend -> Mac.Send;
  AM.SubReceive -> Mac.Receive;
  SplitControl = Mac.SplitControl;

  Mac.Pool = Pool;
}

/* 
 * Local Variables:
 * mode: c
 * End:
 */
