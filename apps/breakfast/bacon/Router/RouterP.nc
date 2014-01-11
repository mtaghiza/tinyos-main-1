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


 #include "AM.h"
 #include "router.h"
 #include "CXRouter.h"
 #include "multiNetwork.h"
 #include "AutoPushDebug.h"
module RouterP{
  uses interface Boot;
  uses interface SplitControl;
  uses interface Receive as ReceiveData;
  uses interface AMPacket;

  uses interface Pool<message_t>;
  uses interface LogWrite;

  uses interface Timer<TMilli>;
  uses interface SettingsStorage;
  uses interface CXDownload;
//  uses interface Receive as CXDownloadReceive;
  uses interface DownloadNotify;
  uses interface Leds;
} implementation {

  event void Boot.booted(){
    #ifndef CC430_PIN_DEBUG
    #define CC430_PIN_DEBUG 0
    #endif
    #if CC430_PIN_DEBUG == 1
    atomic{
      //map SFD to 2.4
      PMAPPWD = PMAPKEY;
      PMAPCTL = PMAPRECFG;
      P2MAP4 = PM_RFGDO0;
      PMAPPWD = 0x00;
  
      //set as output/function
      P2SEL |= BIT4;
      P2DIR |= BIT4;
      
      //clear p1.1, use as gpio
      P1SEL &= ~BIT1;
      P1DIR |=  BIT1;
      P1OUT &= ~BIT1;
    }
    #endif
    call SplitControl.start();
  }

  task void downloadNext(){
    nx_uint32_t downloadInterval;
    downloadInterval = DEFAULT_DOWNLOAD_INTERVAL;
    call SettingsStorage.get(SS_KEY_DOWNLOAD_INTERVAL,
      &downloadInterval, sizeof(downloadInterval));   
    call Timer.startOneShot(downloadInterval);
  }

  event void SplitControl.startDone(error_t error){
     post downloadNext();
  }

  event void Timer.fired(){
    error_t error = call CXDownload.startDownload();
    cinfo(ROUTER, "CXSD %x\r\n", error);
    //getting 6 here
    if (error == ERETRY){
      //This indicates something else was going on (for instance, we
      //were participating in a routers -> BS download) and should be
      //OK to try again momentarily.
      call Timer.startOneShot(DOWNLOAD_RETRY_INTERVAL);
    }else{
      if (error == SUCCESS){
        call Leds.led2On();
      }else{
        call Leds.set(error);
      }
      post downloadNext();
    }
  }

  event void CXDownload.downloadFinished(){
    cinfo(ROUTER, "DF\r\n");
    call Leds.led2Off();
    post downloadNext();
  }

  event void SplitControl.stopDone(error_t error){
  }
  
  message_t* toAppend;
  void* toAppendPl;
  uint8_t toAppendLen;
  
  //TODO: replace with pool/queue
  tunneled_msg_t tunneled_internal;
  tunneled_msg_t* tunneled = &tunneled_internal;

  task void append(){
    error_t error;
    #if DL_AUTOPUSH <= DL_DEBUG && DL_GLOBAL <= DL_DEBUG
    {
      am_addr_t src = call AMPacket.source(toAppend);
      log_record_data_msg_t* dm = (log_record_data_msg_t*)toAppendPl;
      cdbg(AUTOPUSH, "TR %u %lu %u\r\n",
        src, dm->nextCookie, dm->length);
    }
    #endif
    tunneled->recordType = RECORD_TYPE_TUNNELED;
    tunneled->src = call AMPacket.source(toAppend);
    tunneled->amId = call AMPacket.type(toAppend);
    //ugh
    memcpy(tunneled->data, toAppendPl, toAppendLen);
    error = call LogWrite.append(tunneled, 
      sizeof(tunneled_msg_t) - MAX_RECORD_PACKET_LEN + toAppendLen);
    cdbg(ROUTER, "AT %x %u\r\n", error, toAppendLen);
    if (error != SUCCESS){
      call Pool.put(toAppend);
      toAppend = NULL;
    }
  }

  event void LogWrite.appendDone(void* buf, storage_len_t len, bool recordsLost, error_t error){
    call Pool.put(toAppend);
    toAppend = NULL;
    cdbg(ROUTER, "ATD %x\r\n", error);
  }

  event void LogWrite.syncDone(error_t error){}
  event void LogWrite.eraseDone(error_t error){}

  event message_t* ReceiveData.receive(message_t* msg, 
      void* pl, uint8_t len){
    call Leds.led1Toggle();
    if (toAppend == NULL){
      message_t* ret = call Pool.get();
      if (ret){
        cdbg(ROUTER, "RDA\r\n");
        toAppend = msg;
        toAppendPl = pl;
        toAppendLen = len;
        post append();
        return ret;
      }else {
        cwarn(ROUTER, "RDNM\r\n");
        return msg;
      }
    } else {
      cwarn(ROUTER, "RDB\r\n");
      //still handling last packet
      return msg;
    }
  }

//  event message_t* CXDownloadReceive.receive(message_t* msg, 
//      void* pl, uint8_t len){
//    cx_download_t* dpl = (cx_download_t*)pl;
//    cinfo(ROUTER, "CXDR %u\r\n", dpl->networkSegment);
//    if (dpl->networkSegment == NS_SUBNETWORK){
//      signal Timer.fired();
//    }
//    return msg;
//  }
  event void DownloadNotify.downloadStarted(){
    call Leds.led0On();
  }
  task void downloadImmediate(){
    signal Timer.fired();
  }
  event void DownloadNotify.downloadFinished(){
    call Leds.led0Off();
    post downloadImmediate();
  }

  event void CXDownload.eos(am_addr_t owner, eos_status_t status){}
  event void CXDownload.nextAssignment(am_addr_t owner, 
    bool dataPending, uint8_t failedAttempts){}
}
