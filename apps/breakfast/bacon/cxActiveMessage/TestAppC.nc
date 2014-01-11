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

 #include "CX.h"
 #include "schedule.h"
 #include "test.h"
 #include "CXTransport.h"
 #include "stdio.h"

configuration TestAppC{
} implementation {
  components ActiveMessageC;
  components MainC;
  components TestP;
  components SerialPrintfC;
  components PlatformSerialC;
  components LedsC;
  components new TimerMilliC() as StartupTimer;
  components new TimerMilliC() as SendTimer;
  components new TimerMilliC() as SendTimeout;
  components RandomC;

  #if STACK_PROTECTION == 1
  components StackGuardC;
  #else
  #warning Disabling stack protection
  #endif

  TestP.Boot -> MainC;
  TestP.UartStream -> PlatformSerialC;
  TestP.UartControl -> PlatformSerialC;
  TestP.Leds -> LedsC;

  TestP.StartupTimer -> StartupTimer;
  TestP.SendTimer -> SendTimer;
  TestP.SendTimeout -> SendTimeout;
  TestP.Random -> RandomC;
  

  components new AMSenderC(AM_ID_CX_TESTBED) 
    as CXAMSenderC;
  components new AMReceiverC(AM_ID_CX_TESTBED);

  TestP.AMSend -> CXAMSenderC;
  TestP.PacketAcknowledgements -> ActiveMessageC;
  TestP.Receive -> AMReceiverC;

  TestP.Rf1aPacket -> ActiveMessageC.Rf1aPacket;  
  TestP.CXPacket -> ActiveMessageC.CXPacket;
  TestP.CXPacketMetadata -> ActiveMessageC.CXPacketMetadata;
  TestP.Packet -> ActiveMessageC.Packet;
  TestP.SplitControl -> ActiveMessageC.SplitControl;
  
  components CXRoutingTableC;
  TestP.CXRoutingTable -> CXRoutingTableC;
}
