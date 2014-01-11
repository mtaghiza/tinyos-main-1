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


 #include "RecordRequest.h"
 #include "RecordStorage.h"
 #include "AutoPush.h"
 #include "AutoPushDebug.h"
 #include "router.h"

generic module RecordPushRequestP() {
  provides interface Init as SoftwareInit;
  uses interface AMSend;
  uses interface Receive;
  uses interface LogRead;

  uses interface LogWrite;
  uses interface SettingsStorage;
  uses interface LogNotify;

  uses interface Pool<message_t>;
  uses interface Get<am_addr_t>;
  uses interface Packet;
  uses interface CXLinkPacket;

  provides interface Get<uint32_t> as PushCookie;
  provides interface Get<uint32_t> as WriteCookie;
  provides interface Get<uint32_t> as MissingLength;
} implementation {

  enum {
    S_INIT = 0,
    S_IDLE = 1,
    S_SEEKING = 2,
    S_SOUGHT = 3,
    S_READING = 4,
    S_READ = 5,
    S_SENDING = 6,
    S_ERROR = 0xff,
  };
  uint8_t state = S_INIT;
  
  
  log_record_t* recordPtr = NULL;
  message_t* msg = NULL;

  uint8_t* bufferEnd = NULL;
  uint8_t* bufferStart = NULL;
  
  uint16_t recordsLeft = 0;
  uint16_t recordsRead = 0;
  uint8_t totalLen = 0;

  storage_len_t missingLength = 0;

  task void readNext();
  void send();


  enum {
    C_NONE = 0,
    C_PUSH = 1,
    C_REQUEST = 2,
  };
  uint8_t control = C_NONE;

  error_t readFirst(storage_cookie_t cookie, uint16_t length);

  bool requestInQueue = FALSE;
  uint16_t requestLength;
  storage_len_t readLength;
  storage_cookie_t requestCookie;

  bool pushInQueue = FALSE;
  storage_cookie_t pushCookie;

  // by setting pushLength larger than the msg buffer
  // the application will use the maximum available length
  uint8_t pushLength = 0xFF; 
  
  task void processTask();



  command error_t SoftwareInit.init()
  {
    #if ENABLE_CONFIGURABLE_LOG_NOTIFY == 1
    uint16_t highThreshold = DEFAULT_HIGH_PUSH_THRESHOLD;
    uint16_t lowThreshold = DEFAULT_LOW_PUSH_THRESHOLD;

    call SettingsStorage.get(SS_KEY_HIGH_PUSH_THRESHOLD,
      (uint8_t*)(&highThreshold), sizeof(highThreshold));
    call SettingsStorage.get(SS_KEY_LOW_PUSH_THRESHOLD,
      (uint8_t*)(&lowThreshold), sizeof(lowThreshold));

    call LogNotify.setHighThreshold(highThreshold);
    call LogNotify.setLowThreshold(lowThreshold);
    #else
    #warning "Non-configurable auto-push levels"
    #endif

    call LogWrite.sync();
    
    return SUCCESS;
/*
    if (SUCCESS == call LogRead.seek(SEEK_BEGINNING)){
      state = S_INIT;
      
      return SUCCESS;
      
    }else{
      state = S_ERROR;

      return FAIL;
    }
*/
  }


  event void LogWrite.syncDone(error_t error)
  {
    state = S_IDLE;

    pushCookie = call LogWrite.currentOffset();
  }
  
  event void LogRead.seekDone(error_t error)
  {
    if (error != SUCCESS){
      cerror(AUTOPUSH, "sd %x\r\n", error);
    }
    // seekDone either always returns SUCCESS or doesn't return at all
    
    state = S_SOUGHT;
    post readNext();
  }


  event message_t* Receive.receive(message_t* received, void* payload, uint8_t len)
  {
//    {
//      uint8_t i;
//      for(i = 0; i < 10; i++){
//        P1OUT ^= BIT1;
//      }
//    }
    if (!requestInQueue)
    {
      cx_record_request_msg_t *recordRequestPtr = payload;

      requestLength = recordRequestPtr->length;
      requestCookie = recordRequestPtr->cookie;
      cdbg(AUTOPUSH, "req %u %lu\r\n", requestLength, requestCookie);
//      printf("reqLen: %u\r\n", requestLength);
      requestInQueue = TRUE;

      post processTask();
    }else{
      cwarn(AUTOPUSH, "rb\r\n");
    }
    
    return received;
  }


  event void LogNotify.sendRequested(uint16_t left)
  {
    recordsLeft = left;
    if (!pushInQueue)
    {
      pushInQueue = TRUE;

      // push cookie and length are stored in global variables
      
      post processTask();
    }
  }

  task void processTask()
  {
    // when flash is idle, check if there are any unprocessed push
    // or recovery requests queued up. 
    // recovery operations have higher priority than push
    if (state == S_IDLE) {
      if (requestInQueue) {
        cdbg(AUTOPUSH, "riq\r\n");
        if (readFirst(requestCookie, requestLength) == SUCCESS){
          control = C_REQUEST;
        }
      } else if (pushInQueue) {
        cdbg(AUTOPUSH, "piq\r\n");
        // pushCookie is global and read at init and updated at sendDone
        // pushLength is set once during compile
        if (readFirst(pushCookie, pushLength) == SUCCESS){
          control = C_PUSH;
        }
      } else {
        cdbg(AUTOPUSH, "pti\r\n");
        control = C_NONE;
      }
    }else{
      cdbg(AUTOPUSH, "ptb\r\n");
    }
  }

  error_t readFirst(storage_cookie_t cookie, uint16_t length)
  {
    msg = call Pool.get();
    if (msg != NULL)
    {
      call Packet.clear(msg);
      missingLength = length;
      recordsRead = 0;
      totalLen = 0;
      
      // recordPtr points to log_record_data_msg_t->data in the payload buffer
      recordPtr = (log_record_t*)(call AMSend.getPayload(msg, sizeof(log_record_data_msg_t))
                                  + offsetof(log_record_data_msg_t, data));

      if (recordPtr)
      {
        error_t error;
        bufferStart = (uint8_t*)recordPtr; 
        bufferEnd = bufferStart + MAX_RECORD_PACKET_LEN;
        error = call LogRead.seek(cookie);
        if (SUCCESS == error) 
        {
          state = S_SEEKING;

          // SUCCESS, exit function
          return SUCCESS;
        } else {
          cerror(AUTOPUSH, "sf %x\r\n", error);
        }
      }else{
        cerror(AUTOPUSH, "rp0\r\n");
      }
    }    

    // ERROR, no buffer/cannot seek
    return FAIL;
  }         



  task void readNext()
  {
    error_t error;
    // read requested bytes up to the available buffer

    storage_len_t bufferLeft = bufferEnd - (uint8_t*)recordPtr->data;
    readLength = (bufferLeft > missingLength) ? missingLength : bufferLeft;
//    printf("bl %lu ml %lu rl %lu\r\n", 
//      bufferLeft, missingLength, readLength);
    
    //write cookie of current record to buffer.
    recordPtr->cookie = call LogRead.currentOffset();

    //read current record: account for log_record_t's 5-byte header
    // will only return FAIL if LogRead is busy
    error = call LogRead.read(recordPtr->data, readLength);
    if (error != SUCCESS){
      cerror(AUTOPUSH, "rn %x\r\n", error);
    }

    state = S_READING;
  }


  event void LogRead.readDone(void* buf, storage_len_t len, error_t error)
  {

    if( (error == SUCCESS) && (len != 0) )
    { 
      // update record_n length 
      recordPtr->length = len;

      // book keeping for current record message
      missingLength -= len;
      recordsRead++;
      totalLen += len;

      // increment recordPtr to record_n+1
      recordPtr = (log_record_t*)((uint8_t*)recordPtr + (sizeof(log_record_t) + len));
      #if DL_AUTOPUSH <= DL_DEBUG && DL_GLOBAL <= DL_DEBUG
      {
        if ( * ((uint8_t*)buf) == RECORD_TYPE_TUNNELED){
          tunneled_msg_t* tmr = (tunneled_msg_t*)buf;
          if (tmr->amId == AM_LOG_RECORD_DATA_MSG){
            log_record_data_msg_t* tunneled = (log_record_data_msg_t*) tmr->data;
            cdbg(AUTOPUSH, "TF %u %lu %u\r\n", 
              tmr->src, tunneled->nextCookie, tunneled->length);
          }
        }
      }
      #endif
      // is there room for another record in the buffer?
      if ( ((uint8_t*)recordPtr + sizeof(log_record_t) < bufferEnd)
          && (missingLength > 0))
      {
        cdbg(AUTOPUSH, "rdOK more\r\n");
        // try to read the next record
        post readNext();
      } else 
      {
        cdbg(AUTOPUSH, "rdOK go\r\n");
        //no space for another record, send it.
        send();
      }

    } else if (error == SUCCESS && len == 0){
      cdbg(AUTOPUSH, "end\r\n");
//      //rare case where a node keeps sending a packet having length
//      0?
//      missingLength =0;
      send();
    } else {
      //ESIZE: ran out of space in buffer. So, don't clear missingLength. other
      //errors indicate something actually went wrong.
      if (error != ESIZE){
        cerror(AUTOPUSH, "rd %x\r\n", error);
        //a real error occurred
//        printf("rd %x len %lu clear ml\r\n", error, len);
        missingLength = 0;
      }else if (readLength == missingLength){
        cdbg(AUTOPUSH, "rend\r\n");
//        printf("rl==ml == %lu\r\n", readLength);
        //this was the last requested chunk of data: so, there is not
        //enough left in the req to merit another read.
        missingLength =0;
      }else{
        cdbg(AUTOPUSH, "more\r\n");
        //there is more data to be read, so leave missingLength as-is
      }
      
      //no more data or error occured, send what we got
      send();
    } 
  }


  void send()
  {
    log_record_data_msg_t *recordMsgPtr = (log_record_data_msg_t*)
                  (call AMSend.getPayload(msg, sizeof(log_record_data_msg_t)));
    error_t error;

    // set total record message length (used for parsing) and 
    // cookie for next record in flash
    recordMsgPtr->length = recordsRead * sizeof(log_record_t) + totalLen;
    recordMsgPtr->nextCookie = call LogRead.currentOffset();

    if (recordMsgPtr -> length == 0){
      recordsRead = 0;
    }

    state = S_SENDING;
    (call CXLinkPacket.getLinkMetadata(msg))->dataPending = (call LogNotify.getOutstanding() > recordsRead) || requestInQueue;
    // use fixed packet size or variable packet size
    error = call AMSend.send(call Get.get(), 
      msg,
      sizeof(log_record_data_msg_t) + recordMsgPtr->length);
    cdbg(AUTOPUSH, "APX %lu %u\r\n", 
      recordMsgPtr->nextCookie,
      recordMsgPtr->length);
//    error = call AMSend.send(call Get.get(), msg, sizeof(log_record_data_msg_t));
  }


  event void AMSend.sendDone(message_t* msg_, error_t error)
  {
    cdbg(AUTOPUSH, "SD %x\r\n", error);
//    printf("RPR.SendDone: %x %lu\r\n", error, call LocalTime.get());
    call Pool.put(msg);

    switch(control)
    {
      case C_PUSH:
                    pushCookie = call LogRead.currentOffset();
                    call LogNotify.reportSent(recordsRead);
                    if (recordsRead == 0){
//                      printf("none read, force flush\r\n");
                      call LogNotify.forceFlushed();
                    }
                    pushInQueue = FALSE;
                    break;

      case C_REQUEST:
                    requestLength = missingLength;
                    if (missingLength == 0 || recordsRead == 0){
//                      printf("done\r\n");
                      requestInQueue = FALSE;
                    }else{
//                      printf("moar data %lu\r\n", missingLength);
                      requestCookie = call LogRead.currentOffset();
                      //still more data outstanding
                    }
                    //give the LogNotify module a chance to request
                    //more transmissions
                    call LogNotify.reportSent(0);
                    break;
      default:
                    break;
    }                    

    state = S_IDLE;
    post processTask();
  }


  command uint32_t PushCookie.get(){
    return pushCookie;
  }
  command uint32_t WriteCookie.get(){
    return call LogWrite.currentOffset();
  }
  command uint32_t MissingLength.get(){
    return requestLength;
  }
   

  //unused
  event void LogWrite.appendDone(void* buf, storage_len_t len, 
    bool recordsLost, error_t error){}
  event void LogWrite.eraseDone(error_t error){}



}
