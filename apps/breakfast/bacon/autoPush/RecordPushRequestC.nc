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

 
 #include "message.h"
generic configuration RecordPushRequestC(volume_id_t VOLUME_ID, bool circular){
  //external component provides data destination
  uses interface Get<am_addr_t>;
  uses interface Pool<message_t>;
  uses interface AMSend;
  uses interface Packet;
  uses interface CXLinkPacket;
  uses interface Receive;

  provides interface Get<uint32_t> as PushCookie;
  provides interface Get<uint32_t> as WriteCookie;
  provides interface Get<uint32_t> as MissingLength;
} implementation {
  components new LogStorageC(VOLUME_ID, circular);
  components new LogNotifyC(VOLUME_ID);
  components new RecordPushRequestP();
  components SettingsStorageC;

  components MainC;  
  MainC.SoftwareInit -> RecordPushRequestP;

  
  //For finding end of log and setting thresholds
  RecordPushRequestP.LogWrite -> LogStorageC;
  RecordPushRequestP.SettingsStorage -> SettingsStorageC;

  //For deciding when to push
  RecordPushRequestP.LogNotify -> LogNotifyC;

  //For receiving recovery requests
  RecordPushRequestP.Receive = Receive;
  
  //For reading/pushing data
  RecordPushRequestP.AMSend = AMSend;
  RecordPushRequestP.Packet = Packet;
  RecordPushRequestP.CXLinkPacket = CXLinkPacket;
  RecordPushRequestP.LogRead -> LogStorageC;
  RecordPushRequestP.Get = Get;
  RecordPushRequestP.Pool = Pool;

  PushCookie = RecordPushRequestP.PushCookie;
  WriteCookie = RecordPushRequestP.WriteCookie;
  MissingLength = RecordPushRequestP.MissingLength;

}
