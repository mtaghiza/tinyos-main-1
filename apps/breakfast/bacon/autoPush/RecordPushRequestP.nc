
 #include "RecordRequest.h"
 #include "RecordStorage.h"
 #include "AutoPush.h"

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
    uint16_t highThreshold = DEFAULT_HIGH_PUSH_THRESHOLD;
    uint16_t lowThreshold = DEFAULT_LOW_PUSH_THRESHOLD;

    call SettingsStorage.get(SS_KEY_HIGH_PUSH_THRESHOLD,
      (uint8_t*)(&highThreshold), sizeof(highThreshold));
    call SettingsStorage.get(SS_KEY_LOW_PUSH_THRESHOLD,
      (uint8_t*)(&lowThreshold), sizeof(lowThreshold));

    call LogNotify.setHighThreshold(highThreshold);
    call LogNotify.setLowThreshold(lowThreshold);

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
    // seekDone either always returns SUCCESS or doesn't return at all
    
    state = S_SOUGHT;
    post readNext();
  }


  event message_t* Receive.receive(message_t* received, void* payload, uint8_t len)
  {
    if (!requestInQueue)
    {
      cx_record_request_msg_t *recordRequestPtr = payload;

      requestLength = recordRequestPtr->length;
      requestCookie = recordRequestPtr->cookie;
//      printf("reqLen: %u\r\n", requestLength);
      requestInQueue = TRUE;

      post processTask();
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
        if (readFirst(requestCookie, requestLength) == SUCCESS){
          control = C_REQUEST;
        }
      } else if (pushInQueue) {
        // pushCookie is global and read at init and updated at sendDone
        // pushLength is set once during compile
        if (readFirst(pushCookie, pushLength) == SUCCESS){
          control = C_PUSH;
        }
      } else {
        control = C_NONE;
      }
    }
  }

  error_t readFirst(storage_cookie_t cookie, uint16_t length)
  {
    msg = call Pool.get();
//    printf("rf %u\r\n", length);
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
        bufferStart = (uint8_t*)recordPtr; 
        bufferEnd = bufferStart + sizeof(((log_record_data_msg_t*)recordPtr)->data); 

        if (SUCCESS == call LogRead.seek(cookie)) 
        {
          state = S_SEEKING;

          // SUCCESS, exit function
          return SUCCESS;
        } 
      }
    }    

    // ERROR, no buffer/cannot seek
    return FAIL;
  }         



  task void readNext()
  {
    // read requested bytes up to the available buffer

    storage_len_t bufferLeft = bufferEnd - (uint8_t*)recordPtr->data;
    readLength = (bufferLeft > missingLength) ? missingLength : bufferLeft;
//    printf("bl %lu ml %lu rl %lu\r\n", 
//      bufferLeft, missingLength, readLength);
    
    //write cookie of current record to buffer.
    recordPtr->cookie = call LogRead.currentOffset();

    //read current record: account for log_record_t's 5-byte header
    // will only return FAIL if LogRead is busy
    call LogRead.read(recordPtr->data, readLength);

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

    } else {
      //ESIZE: ran out of space in buffer. So, don't clear missingLength. other
      //errors indicate something actually went wrong.
      if (error != ESIZE){
        //a real error occurred
//        printf("rd %x len %lu clear ml\r\n", error, len);
        missingLength = 0;
      }else if (readLength == missingLength){
//        printf("rl==ml == %lu\r\n", readLength);
        //this was the last requested chunk of data: so, there is not
        //enough left in the req to merit another read.
        missingLength =0;
      }else{
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

    state = S_SENDING;
    
    (call CXLinkPacket.getLinkMetadata(msg))->dataPending = (recordsLeft > recordsRead);
    // use fixed packet size or variable packet size
//    call AMSend.send(call Get.get(), msg, (uint8_t*)recordPtr - bufferStart);
    error = call AMSend.send(call Get.get(), msg, sizeof(log_record_data_msg_t));
//    printf("RPR.Send: %x %u %lu %u %lu\r\n", 
//      error,
//      recordMsgPtr->length, 
//      recordMsgPtr->nextCookie, 
//      recordsRead, 
//      call LocalTime.get());
  }


  event void AMSend.sendDone(message_t* msg_, error_t error)
  {
//    printf("RPR.SendDone: %x %lu\r\n", error, call LocalTime.get());
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
                    if (missingLength == 0){
//                      printf("done\r\n");
                      requestInQueue = FALSE;
                    }else{
//                      printf("moar data %lu\r\n", missingLength);
                      requestLength = missingLength;
                      requestCookie = call LogRead.currentOffset();
                      //still more data outstanding
                    }
                    break;
      default:
                    break;
    }                    

    state = S_IDLE;
    post processTask();
  }


  

   

  //unused
  event void LogWrite.appendDone(void* buf, storage_len_t len, 
    bool recordsLost, error_t error){}
  event void LogWrite.eraseDone(error_t error){}



}
