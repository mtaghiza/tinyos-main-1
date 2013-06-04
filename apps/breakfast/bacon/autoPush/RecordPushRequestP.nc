#include "RecordRequest.h"
#include "RecordStorage.h"
#include "AutoPush.h"

generic module RecordPushRequestP() {
  uses interface Boot;
  uses interface AMSend;
  uses interface Receive;
  uses interface LogRead;

  uses interface LogWrite;
  uses interface SettingsStorage;
  uses interface LogNotify;

  uses interface Pool<message_t>;
  uses interface Get<am_addr_t>;
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

  uint16_t recordsRead = 0;
  uint8_t totalLen = 0;

  uint8_t missingLength = 0;

  task void readNext();
  void send();


  enum {
    C_NONE = 0,
    C_PUSH = 1,
    C_REQUEST = 2,
  };
  uint8_t control = C_NONE;

  void readFirst(storage_cookie_t cookie, uint8_t length);

  bool requestInQueue = FALSE;
  uint8_t requestLength;
  storage_cookie_t requestCookie;

  bool pushInQueue = FALSE;
  storage_cookie_t pushCookie;

  // by setting pushLength larger than the msg buffer
  // the application will use the maximum available length
  uint8_t pushLength = 0xFF; 
  
  task void processTask();



  event void Boot.booted()
  {
    uint16_t highThreshold = DEFAULT_HIGH_PUSH_THRESHOLD;
    uint16_t lowThreshold = DEFAULT_LOW_PUSH_THRESHOLD;

    call SettingsStorage.get(SS_KEY_HIGH_PUSH_THRESHOLD,
      (uint8_t*)(&highThreshold), sizeof(highThreshold));
    call SettingsStorage.get(SS_KEY_LOW_PUSH_THRESHOLD,
      (uint8_t*)(&lowThreshold), sizeof(lowThreshold));

    call LogNotify.setHighThreshold(highThreshold);
    call LogNotify.setLowThreshold(lowThreshold);

    if (SUCCESS == call LogRead.seek(SEEK_BEGINNING)){
      state = S_INIT;
    }else{
      state = S_ERROR;
    }
  }


  
  event void LogRead.seekDone(error_t error)
  {
    if (error == SUCCESS)
    {
      if (state == S_INIT)
      {
        state = S_IDLE;

        pushCookie = call LogWrite.currentOffset();

      } else if (state == S_SEEKING)
      {
        state = S_SOUGHT;
        post readNext();

      } else {
        state = S_ERROR;
      }
    } else {
      state = S_ERROR;
    }
  }


  event message_t* Receive.receive(message_t* received, void* payload, uint8_t len)
  {
    if (!requestInQueue)
    {
      cx_record_request_msg_t *recordRequestPtr = payload;

      requestLength = recordRequestPtr->length;
      requestCookie = recordRequestPtr->cookie;

      requestInQueue = TRUE;

      post processTask();
    }
    
    return received;
  }


  event void LogNotify.sendRequested(uint16_t left)
  {
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
    // push operations have higher priority than recovery requests  
    if (state == S_IDLE)
    {
      if (pushInQueue)
      {
        control = C_PUSH;

        // pushCookie is global and read at init and updated at sendDone
        // pushLength is set once during compile
        readFirst(pushCookie, pushLength);

      } else if (requestInQueue)
      {
        control = C_REQUEST;

        readFirst(requestCookie, requestLength);
      }
      else
      {
        control = C_NONE;
      }
    }
  }

  void readFirst(storage_cookie_t cookie, uint8_t length)
  {
    msg = call Pool.get();

    if (msg != NULL)
    {
      missingLength = length;
      recordsRead = 0;
      totalLen = 0;
      
      // recordPtr points to log_record_data_msg_t->data in the payload buffer
      recordPtr = (log_record_t*)(call AMSend.getPayload(msg, sizeof(log_record_data_msg_t))
                                  + offsetof(log_record_data_msg_t, data));

      if (recordPtr)
      {
        bufferStart = (uint8_t*)recordPtr; 
        bufferEnd = bufferStart + sizeof(((log_record_data_msg_t*)recordPtr)->data); 

        if (SUCCESS == call LogRead.seek(cookie)) 
        {
          state = S_SEEKING;

          // SUCCESS, exit function
          return;
        } 
      }
    }    

    // ERROR, no buffer/cannot seek
    state = S_ERROR;
    call LogNotify.forceFlushed();
  }         



  task void readNext()
  {
    // read requested bytes up to the available buffer

    storage_len_t bufferLeft = bufferEnd - (uint8_t*)recordPtr->data;
    storage_len_t readLength = (bufferLeft > missingLength) ? missingLength : bufferLeft;
    
    //write cookie of current record to buffer.
    recordPtr->cookie = call LogRead.currentOffset();

    //read current record: account for log_record_t's 5-byte header
    if (SUCCESS == call LogRead.read(recordPtr->data, readLength))
    {
      state = S_READING;
    } else {
      state = S_ERROR;
    }
  }


  event void LogRead.readDone(void* buf, storage_len_t len, error_t error)
  {

    if( (error == SUCCESS) && (len != 0) )
    {
      state = S_READ;

      // update record_n length 
      recordPtr->length = len;

      // book keeping for current record message
      missingLength -= len;
      recordsRead++;
      totalLen += len;

      // increment recordPtr to record_n+1
      recordPtr = (log_record_t*)((uint8_t*)recordPtr + (sizeof(log_record_t) + len));

      // is there room for another record in the buffer?
      if ( ((uint8_t*)recordPtr + sizeof(log_record_t) < bufferEnd)
          && (missingLength > 0))
      {
        // try to read the next record
        post readNext();
      } else 
      {
        //no space for another record, send it.
        send();
      }

    } else if ( (len == 0) )
    {
      //no more data or error occured, send what we got
      send();
    } else {
      state = S_ERROR;
    }
  }


  void send()
  {
    log_record_data_msg_t *recordMsgPtr = (log_record_data_msg_t*)
                  (call AMSend.getPayload(msg, sizeof(log_record_data_msg_t)));

    // set total record message length (used for parsing) and 
    // cookie for next record in flash
    recordMsgPtr->length = recordsRead * sizeof(log_record_t) + totalLen;
    recordMsgPtr->nextCookie = call LogRead.currentOffset();

    state = S_SENDING;

    // use fixed packet size or variable packet size
//    call AMSend.send(call Get.get(), msg, (uint8_t*)recordPtr - bufferStart);
    call AMSend.send(call Get.get(), msg, sizeof(log_record_data_msg_t));
  }


  event void AMSend.sendDone(message_t* msg_, error_t error)
  {
    call Pool.put(msg);

    switch(control)
    {
      case C_PUSH:
                    pushCookie = call LogRead.currentOffset();
                    call LogNotify.reportSent(recordsRead);
                    if (recordsRead == 0){
                      printf("none read, force flush\r\n");
                      call LogNotify.forceFlushed();
                    }
                    pushInQueue = FALSE;
                    break;

      case C_REQUEST:
                    requestInQueue = FALSE;
                    break;
      default:
                    break;
    }                    

    state = S_IDLE;
    post processTask();
  }


  

   

  //unused
  event void LogWrite.syncDone(error_t error){}
  event void LogWrite.appendDone(void* buf, storage_len_t len, 
    bool recordsLost, error_t error){}
  event void LogWrite.eraseDone(error_t error){}



}
