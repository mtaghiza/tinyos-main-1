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


 #include "StorageVolumes.h"
 #include "RecordStorage.h"
 #include "message.h"
 #include "stdio.h"
// #define printf(...)
configuration TestAppC{
} implementation {
  components new ToastSamplerC(VOLUME_RECORD, TRUE);
  components MainC;
  components TestP;

  components WatchDogC;

  components SerialPrintfC;
  components SerialStartC;

  components Msp430XV2ClockC;

  TestP.Boot -> MainC;
  TestP.Msp430XV2ClockControl -> Msp430XV2ClockC;

  components new PoolC(message_t, 2);

  components new LogStorageC(VOLUME_RECORD, TRUE);
  components SettingsStorageC;
  SettingsStorageC.LogWrite -> LogStorageC;

//  components SerialActiveMessageC;
//  components new SerialAMSenderC(AM_LOG_RECORD_DATA_MSG) as AMSenderC;
//
//  TestP.SplitControl -> SerialActiveMessageC;

//  components new RecordPushRequestC(VOLUME_RECORD, TRUE);
//  RecordPushRequestC.AMSend -> AMSenderC;
//  RecordPushRequestC.Pool -> PoolC;
//  RecordPushRequestC.Get -> TestP.Get;

}
