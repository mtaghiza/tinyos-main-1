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

#include "testAutoPush.h"
#include "StorageVolumes.h"

configuration TestAppC{
} implementation {
  components MainC;
  
  components PrintfC;
  components SerialStartC;
  components WatchDogC;

  components new PoolC(message_t, 4);

  components SerialActiveMessageC;

/*
  components new SerialAMSenderC(AM_LOG_RECORD_DATA_MSG) as AMSenderC;
  components new AutoPushC(VOLUME_TEST, TRUE);
  AutoPushC.AMSend -> AMSenderC;
  AutoPushC.Pool -> PoolC;
  AutoPushC.Get -> TestP.Get;
*/

  components new RecordPushRequestC(VOLUME_TEST, TRUE);
  components new SerialAMSenderC(AM_LOG_RECORD_DATA_MSG) as RecoverSenderC;
  components new SerialAMReceiverC(AM_CX_RECORD_REQUEST_MSG) as RecoverReceiverC;
  RecordPushRequestC.AMSend -> RecoverSenderC;
  RecordPushRequestC.Receive -> RecoverReceiverC;
  RecordPushRequestC.Pool -> PoolC;
  RecordPushRequestC.Get -> TestP.Get;


  components TestP;
  components new LogStorageC(VOLUME_TEST, TRUE);
  components new TimerMilliC();

  TestP.Boot -> MainC;
  TestP.LogWrite -> LogStorageC;
  TestP.Timer -> TimerMilliC;
  TestP.SplitControl -> SerialActiveMessageC;
}
