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

generic configuration ToastSamplerC(volume_id_t VOLUME_ID, bool circular){
} implementation {
   

  components ToastSamplerP;
  components MainC;
  components new TimerMilliC();
  components new TimerMilliC() as StartupTimer;

  ToastSamplerP.Boot -> MainC;
  ToastSamplerP.Timer -> TimerMilliC;
  ToastSamplerP.StartupTimer -> StartupTimer;

  //result storage
  components new LogStorageC(VOLUME_ID, circular);
  ToastSamplerP.LogWrite -> LogStorageC;
  
  //power/discovery
  components PlatformBusPowerP;
  ToastSamplerP.SplitControl -> PlatformBusPowerP;
  components new I2CDiscovererC();
  ToastSamplerP.I2CDiscoverer -> I2CDiscovererC;
  
  //Metadata discovery
  components I2CTLVStorageMasterC;
  ToastSamplerP.I2CTLVStorageMaster -> I2CTLVStorageMasterC;
  ToastSamplerP.TLVUtils -> I2CTLVStorageMasterC;
  
  //sampling
  components I2CADCReaderMasterC;
  ToastSamplerP.I2CADCReaderMaster -> I2CADCReaderMasterC;

  #if ENABLE_PRECISION_TIMESTAMP == 1
  //time-synch
  components I2CSynchMasterC;
  ToastSamplerP.I2CSynchMaster -> I2CSynchMasterC;
  #else 
  #warning Disable precision-timestamped samples.
  #endif

  //sampling settings
  components SettingsStorageC;
  ToastSamplerP.SettingsStorage -> SettingsStorageC;

  components RebootCounterC;

//  //DEBUG
//  components new LogPrintfC(VOLUME_ID, circular);
//  ToastSamplerP.LogPrintf -> LogPrintfC;
}
