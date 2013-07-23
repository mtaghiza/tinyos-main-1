
 #include <stdio.h>
 #include "decodeError.h"
 #include "AM.h"
 #include "GlobalID.h"
module InitTestbedP
{
  uses {
    interface Boot;
    interface LogWrite;
    //interface LogRead;
    interface Leds;
    interface StdControl as UartCtl;
    interface UartStream;
    interface Timer<TMilli>;
    interface SettingsStorage;
    interface Get<uint16_t> as RebootCounter;
  }
}

implementation
{
  task void formatTask();

  event void Timer.fired(){
    post formatTask();
  }

  event void Boot.booted()
  {
    uint8_t globalId[8]={0,0,0,0,0,0,0,0};
    uint8_t validate[8];
    printf("Testbed Init node %x\r\n", TOS_NODE_ID);
    call UartCtl.start();
    *((am_addr_t*)globalId) = TOS_NODE_ID;
    call SettingsStorage.set(TAG_GLOBAL_ID, globalId, 8);
    call SettingsStorage.get(TAG_GLOBAL_ID, validate, 8);
    {
      uint8_t i;
      for (i = 0; i < 8; i++){
        printf("%x : %x\r\n", globalId[i], validate[i]);
      }
    }
    if (*((am_addr_t*)globalId) == TOS_NODE_ID){
      printf("Barcode written\r\n");
      if (AUTOMATIC){
        call Timer.startOneShot(1024);
      }else{
        printf("USAGE\r\n");
        printf("=====\r\n");
        printf("q: reset\r\n");
        printf("f: format\r\n");
      }
    }else{
      printf("failed to write barcode, not formatting\r\n");
    }
  }

  async event void UartStream.receivedByte(uint8_t byte){
    switch(byte){
      case 'q':
        WDTCTL = 0;
        break;
      case 'f':
        post formatTask();
        break;
      case '\r':
        printf("\n\r");
        break;
      default:
        printf("%c", byte);
    }
  }

  task void formatTask(){
    error_t err = call LogWrite.erase();
    printf("Erase: %x %s\n\r", err, decodeError(err));
    if (err == SUCCESS){
      call Leds.set(2);   // _G_
    } else {
      call Leds.set(7);   // BGR
    }
  }
  event void LogWrite.eraseDone(error_t err)
  {
    printf("EraseDone: %x %s\n\r", err, decodeError(err));
    if (err == SUCCESS) {
      call Leds.set(4);   // B__
    } else {
      call Leds.set(7);   // BGR
    }
  }
  
  //event void LogRead.readDone(void* buf, storage_len_t len, error_t error) {}
  //event void LogRead.seekDone(error_t error) {}
  
  event void LogWrite.syncDone(error_t error) {}
  event void LogWrite.appendDone(void* buf, storage_len_t len, bool recordsLost, error_t error) {}
  async event void UartStream.receiveDone(uint8_t* buf, uint16_t len, error_t err){}
  async event void UartStream.sendDone(uint8_t* buf, uint16_t len, error_t err){}
}
