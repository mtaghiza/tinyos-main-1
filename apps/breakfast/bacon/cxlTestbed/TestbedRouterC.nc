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


 #include "testbed.h"
 #include "autosender.h"
configuration TestbedRouterC{
} implementation {
  components TestbedRouterP;
  components CXRouterC;
  components SlotSchedulerC;
  components new RouterAMSenderC(AM_TEST_MSG) as AMSenderC;
  components new AMReceiverC(AM_TEST_MSG);

  TestbedRouterP.CXDownload -> CXRouterC.CXDownload[NS_SUBNETWORK];
  TestbedRouterP.DownloadNotify -> SlotSchedulerC.DownloadNotify[NS_ROUTER];
  TestbedRouterP.Receive -> AMReceiverC;
  TestbedRouterP.AMSend -> AMSenderC;

  components ActiveMessageC;
  components CXLinkPacketC;
  TestbedRouterP.Pool -> ActiveMessageC;
  TestbedRouterP.CXLinkPacket -> CXLinkPacketC;
  TestbedRouterP.Packet -> AMSenderC;
  TestbedRouterP.Get -> CXRouterC.Get[NS_ROUTER];

  components new TimerMilliC();
  TestbedRouterP.Timer -> TimerMilliC;
  
}
