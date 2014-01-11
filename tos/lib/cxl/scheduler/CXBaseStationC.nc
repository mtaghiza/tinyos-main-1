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

configuration CXBaseStationC {

  provides interface SplitControl;
  provides interface Send;
  provides interface Packet;
  provides interface Receive;

  provides interface CXDownload[uint8_t ns];

  uses interface Pool<message_t>;
  provides interface CTS[uint8_t ns];

  provides interface Receive as StatusReceive;
  provides interface Get<am_addr_t>[uint8_t ns];

  uses interface LogWrite;
} implementation {
  components SlotSchedulerC;
  components CXProbeScheduleC;

  components CXMasterP;
  CXMasterP.GetProbeSchedule -> CXProbeScheduleC;
  components CXLinkPacketC;
  CXMasterP.CXLinkPacket -> CXLinkPacketC;

  components LedsC, NoLedsC;
  CXMasterP.Leds -> NoLedsC;

  CXDownload[NS_GLOBAL] = CXMasterP.CXDownload[NS_GLOBAL];
  CXDownload[NS_SUBNETWORK] = CXMasterP.CXDownload[NS_SUBNETWORK];
  CXDownload[NS_ROUTER] = CXMasterP.CXDownload[NS_ROUTER];

  CXMasterP.Neighborhood -> SlotSchedulerC;
  LogWrite = CXMasterP.LogWrite;

  Send = SlotSchedulerC;
  Packet = SlotSchedulerC;
  Receive = SlotSchedulerC;
  SplitControl = SlotSchedulerC;

  SlotSchedulerC.Pool = Pool;

  SlotSchedulerC.SlotController[NS_GLOBAL] -> CXMasterP;
  SlotSchedulerC.SlotController[NS_SUBNETWORK] -> CXMasterP;
  SlotSchedulerC.SlotController[NS_ROUTER] -> CXMasterP;

  components CXWakeupC;
  CXMasterP.LppControl -> CXWakeupC;

  components CXAMAddressC;
  CXMasterP.ActiveMessageAddress -> CXAMAddressC;

  CTS[NS_GLOBAL] = CXMasterP.CTS[NS_GLOBAL];
  CTS[NS_SUBNETWORK] = CXMasterP.CTS[NS_SUBNETWORK];
  CTS[NS_ROUTER] = CXMasterP.CTS[NS_ROUTER];

  StatusReceive = CXMasterP.Receive;
  Get = CXMasterP.GetRoot;

  components SettingsStorageC;
  CXMasterP.SettingsStorage -> SettingsStorageC;
}
