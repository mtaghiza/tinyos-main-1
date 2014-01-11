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
#include "InternalFlash.h"
#include "TLVStorage.h"
#include "decodeError.h"
#include "GlobalID.h"

module TestP{
  uses interface Boot;
  uses interface UartStream;
  uses interface StdControl;
  uses interface GlobalID;
} implementation {
  uint8_t lsb;

  event void Boot.booted(){
   call StdControl.start();
   printf("GlobalID test\n\r");
  }

  async event void UartStream.sendDone(uint8_t* buf, uint16_t len, error_t err){
  }

  task void readGlobalID(){
    uint8_t globalID[GLOBAL_ID_LEN];
    uint8_t i;
    error_t error;
    error = call GlobalID.getID(globalID, GLOBAL_ID_LEN);
    printf("getID: %s\n\r", decodeError(error));
    if (error == SUCCESS){
      printf("Global ID: \n\r");
      for (i = 0; i < GLOBAL_ID_LEN; i++){
        printf(" %x\n\r", globalID[i]);
      }
    }
  }
  
  task void setGlobalID(){
    uint8_t gid[GLOBAL_ID_LEN];
    memset(gid, 0, GLOBAL_ID_LEN);
    gid[GLOBAL_ID_LEN-1] = lsb;
    printf("Set ID: %s\n\r", 
      decodeError( call GlobalID.setID(gid, GLOBAL_ID_LEN)));
  }

  async event void UartStream.receivedByte(uint8_t byte){
    switch(byte){
      case '\r':
        printf("\n\r");
        break;
      case 's':
        post setGlobalID();
        break;
      case 'r':
        post readGlobalID();
        break;
      case 'q':
        WDTCTL = 0;
        break;
      case 'i':
        lsb ++;
        printf("LSB %x\n\r", lsb);
        break;
      default:
        printf("%c", byte);
    }
  }

  async event void UartStream.receiveDone(uint8_t* buf, uint16_t len, error_t err){
  }

}
