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

#include <stdio.h>
module TestP{
  uses interface Boot;
  uses interface Leds;
  uses interface Timer<TMilli>;

  uses interface StdControl as SerialControl;
  uses interface UartStream;
  
  uses interface LogRead;
  uses interface LogWrite;

  uses interface LogNotify;
} implementation {
  storage_addr_t seekLoc = SEEK_BEGINNING;
  bool seekPending;

  uint16_t highThresh;
  bool highPending;
  uint16_t lowThresh;
  bool lowPending;
  uint32_t appendStop;
  bool appendPending;
 
  enum{
    MAX_RECORD_LEN=0x0F,
  };

  typedef nx_struct test_record_t{
    nx_uint8_t recordType;
    nx_uint8_t val[MAX_RECORD_LEN];
  } test_record_t;

  test_record_t record_internal;
  test_record_t* record = &record_internal;

  uint8_t genBuf[254];

  uint8_t curRL = 1;
   
  task void appendTask();
  event void LogNotify.sendRequested(uint16_t requested){
    printf("sr: %u\r\n", requested);
  }

  void printRecord(test_record_t* r){
    printf("%x", r->recordType);
    {
      uint8_t i;
      for (i = 0; i < MAX_RECORD_LEN; i++){
        printf(" %x", r->val[i]);
      }
    }
    printf("\r\n");
  }

  void fillRecord(test_record_t* r, uint8_t len){
    uint8_t i;
    memset(r->val, 0, MAX_RECORD_LEN);
    r->recordType = len|0x80;
    for (i=0; i<len; i++){
      r->val[i] = i;
    }
  }

  event void Boot.booted(){
    printf("Commands\r\n");
    printf("  q: reset\r\n");
    printf("  s[0-9]*\\n: seek to provided location\r\n");
    printf("  h[0-9]*\\n: set high log notify threshold\r\n");
    printf("  l[0-9]*\\n: set low log notify threshold\r\n");
    printf("  f: inform log notify that one record was sent\r\n");
    printf("  e: erase log\r\n");
    printf("  a: append to log\r\n");
    printf("  A[0-9]*\\n: append multiple records until write cookie exceeds supplied value\r\n");
    printf("  r: read\r\n");
    printf("  ?: print current state info\r\n");
    fillRecord(record, curRL);
    printRecord(record);
  }

  task void printState(){
    printf("\r\n");
    printf("====== CURRENT STATE ========\r\n");
    printRecord(record);
    printf("len: %u\r\n", curRL);
    printf("Read pos: %lu\r\n", call LogRead.currentOffset());
    printf("Write pos: %lu\r\n", call LogWrite.currentOffset());
  }

  event void Timer.fired(){
  }

  event void LogRead.readDone(void* buf, storage_len_t len, error_t error){
    uint8_t i;
    if (error == SUCCESS){
      printf("RD:");
      for (i = 0; i < len; i++){
        printf(" %02X", ((uint8_t*)buf)[i]);
      }
      printf("\r\n");
    } else{
      printf("lr.rd: %x\r\n", error);
    }
  }

  event void LogRead.seekDone(error_t error){
    printf("seek done %x\r\n", error);
  }

  event void LogWrite.appendDone(void* buf, storage_len_t len, bool recordsLost,
			error_t error){
    printf("append done: %x\r\n", error);
    curRL = (1+curRL)%(MAX_RECORD_LEN);
    if (call LogWrite.currentOffset() > appendStop){
      appendPending = FALSE;
    }else{
      post appendTask();
    }
  }

  event void LogWrite.eraseDone(error_t error){
    printf("Erase done %x\r\n", error);
  }

  event void LogWrite.syncDone(error_t error){
  }

  task void seekTask(){
    storage_addr_t sl;
    atomic{
      sl = seekLoc;
      seekLoc = 0;
      seekPending = FALSE;
    }
    printf("seeking to %lu : %x\r\n", 
      sl, call LogRead.seek(sl));
  }

  task void readTask(){
    printf("read (%lu):", call LogRead.currentOffset());
    printf(" %x\r\n", 
      call LogRead.read(genBuf, 254));
  }

  task void littleReadTask(){
    printf("little-read (%lu):", call LogRead.currentOffset());
    printf(" %x\r\n", 
      call LogRead.read(genBuf, 3));
  }

  task void appendTask(){
    printf("append (%lu left)\r\n", 
      appendStop - call LogWrite.currentOffset());
    fillRecord(record, curRL);
    call LogWrite.append(record, curRL + sizeof(record->recordType));
  }

  task void eraseTask(){
    printf("erase\r\n");
    call LogWrite.erase();
  }

  task void lowTask(){
    uint16_t lt;
    atomic{
      lt = lowThresh;
      lowThresh = 0;
      lowPending = FALSE;
    }
    printf("Set Low(%u): %x\r\n", 
      lt,
      call LogNotify.setLowThreshold(lt));
  }

  task void highTask(){
    uint16_t ht;
    atomic{
      ht = highThresh;
      highThresh = 0;
      highPending = FALSE;
    }
    printf("Set high(%u): %x\r\n", 
      ht,
      call LogNotify.setHighThreshold(ht));
  }

  task void flushTask(){
    printf("flushing one record: %x\r\n", 
      call LogNotify.reportSent(1));
  }
  
  async event void UartStream.receivedByte(uint8_t byte){
    switch ( byte ){
      case 'q':
        atomic{
          WDTCTL = 0;
        }
        break;
      case 's':
        printf("%c>", byte);
        seekPending = TRUE;
        seekLoc = 0;
        break;
      case 'h':
        printf("%c>", byte);
        highPending = TRUE;
        highThresh = 0;
        break;
      case 'l':
        printf("%c>", byte);
        lowPending = TRUE;
        lowThresh = 0;
        break;
      case 'e':
        post eraseTask();
        break;
      case 'a':
        appendStop = 0;
        post appendTask();
        break;
      case 'A':
        printf("%c>", byte);
        appendPending = TRUE;
        appendStop = 0;
        break;
      case 'r':
        post readTask();
        break;
      case 'f':
        post flushTask();
        break;
      case 'R':
        post littleReadTask();
        break;
      case '?':
        post printState();
        break;
      case '\r':
        printf("\r\n");
        if (seekPending){
          post seekTask();
        }else if (lowPending){
          post lowTask();
        } else if (highPending){
          post highTask();
        }else if (appendPending){
          post appendTask();
        }
        break;
      default:
        printf("%c", byte);
        
        if ( byte >= '0' && byte <= '9'){
          if (seekPending){
            seekLoc = (seekLoc *10)+ (byte-'0');
          } else if (lowPending){
            lowThresh = (lowThresh*10) + (byte - '0');
          } else if (highPending){
            highThresh = (highThresh*10) + (byte -'0');
          }else if (appendPending){
            appendStop = (appendStop*10) + (byte - '0');
          }
        }
        break;
    }
  }
  
  async event void UartStream.receiveDone( uint8_t* buf, uint16_t len,
    error_t error ){}
  async event void UartStream.sendDone( uint8_t* buf, uint16_t len,
    error_t error ){}
 
}
