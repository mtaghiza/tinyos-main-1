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


  #include "SettingsStorage.h"
  #include "message.h"

configuration SettingsStorageConfiguratorC {
  uses interface Pool<message_t>;
} implementation {
  components SettingsStorageC;

  components new AMReceiverC(AM_SET_SETTINGS_STORAGE_MSG) 
    as SetReceive;
  #ifndef ENABLE_SETTINGS_CONFIG_FULL
  #define ENABLE_SETTINGS_CONFIG_FULL 1
  #endif

  #if ENABLE_SETTINGS_CONFIG_FULL == 1
  components new AMReceiverC(AM_GET_SETTINGS_STORAGE_CMD_MSG) 
    as GetReceive;
  components new AMSenderC(AM_GET_SETTINGS_STORAGE_RESPONSE_MSG) 
    as GetSend;
  components new AMReceiverC(AM_CLEAR_SETTINGS_STORAGE_MSG) 
    as ClearReceive;
  #else
  #warning SettingsStorage: no clear/get support.
  #endif

  components SettingsStorageConfiguratorP;
  
  SettingsStorageConfiguratorP.SettingsStorage -> SettingsStorageC;
  SettingsStorageConfiguratorP.SetReceive -> SetReceive;
  #if ENABLE_SETTINGS_CONFIG_FULL == 1
  SettingsStorageConfiguratorP.GetReceive -> GetReceive;
  SettingsStorageConfiguratorP.GetSend -> GetSend;
  SettingsStorageConfiguratorP.ClearReceive -> ClearReceive;
  #else
  #endif

  SettingsStorageConfiguratorP.AMPacket -> SetReceive;

  SettingsStorageConfiguratorP.Pool = Pool;
}
