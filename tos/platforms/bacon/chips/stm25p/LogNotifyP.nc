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

generic module LogNotifyP(){
  provides interface LogNotify as RecordsNotify;
//  provides interface LogNotify as BytesNotify;

  provides interface Init;
  uses interface Notify<uint8_t> as SubNotify;
} implementation {
  enum {
    S_FILLING = 0,
    S_DRAINING = 1,
  };
  
  uint8_t recordState = S_FILLING;
  uint16_t outstandingRecords = 0;
  uint16_t recordLow = 1;
  uint16_t recordHigh = 0xFFFF;
//  uint16_t outstandingBytes = 0;

  void checkRecordState(bool repostOK);

  task void recordSendRequest(){
    signal RecordsNotify.sendRequested(outstandingRecords);
  }

  command uint16_t RecordsNotify.getOutstanding(){
    return outstandingRecords;
  }

  command error_t RecordsNotify.setHighThreshold(uint16_t thresh){
    if (thresh >= recordLow){
      recordHigh = thresh;
      checkRecordState(FALSE);
      return SUCCESS;
    } else {
      return EINVAL;
    }
  }

  command error_t RecordsNotify.setLowThreshold(uint16_t thresh){
    if (thresh <= recordHigh){
      recordLow = thresh;
      checkRecordState(FALSE);
      return SUCCESS;
    } else {
      return EINVAL;
    }
  }

  command error_t RecordsNotify.reportSent(uint16_t sent){
    if (sent <= outstandingRecords){
      outstandingRecords -= sent;
      checkRecordState(TRUE);
      return SUCCESS;
    }else{
      outstandingRecords = 0;
      return EINVAL;
    }
  }

  command void RecordsNotify.forceFlushed(){
    outstandingRecords = 0;
    checkRecordState(FALSE);
  }

  command error_t Init.init(){
    return call SubNotify.enable();
  }
  
  void checkRecordState(bool repostOK){
    //just passed upper threshold: start draining
    if (outstandingRecords >= recordHigh && recordState == S_FILLING){
      recordState = S_DRAINING;
    }
    //just passed lower threshold: start filling
    if (outstandingRecords < recordLow && recordState == S_DRAINING){
      recordState = S_FILLING;
    } 
    
    if (recordState == S_DRAINING && repostOK){
      post recordSendRequest();
    }
  }

  event void SubNotify.notify(uint8_t bytesWritten){
    outstandingRecords += 1;
    checkRecordState((outstandingRecords == recordHigh));
//    outstandingBytes += bytesWritten;
  }

  default event void RecordsNotify.sendRequested(uint16_t requested){}


}
