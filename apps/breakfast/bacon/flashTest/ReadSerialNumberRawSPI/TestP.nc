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
  uses interface GeneralIO as CSN;
  uses interface GeneralIO as Power;
  uses interface SpiByte;
  uses interface SpiPacket;
  uses interface Resource;
  uses interface Timer<TMilli>;
  uses interface Leds;
} implementation {
  //forward declarations
  task void readSerialTask();
  task void reportIDTask();

  #define ID_LEN 20
  #define S_RDID 0x9F
  uint8_t id_buf[ID_LEN];

  event void Boot.booted(){
    call Leds.led0On();
    call Timer.startPeriodic(1024);
    call CSN.makeOutput();
    call CSN.set();
    call Power.makeOutput();
    call Power.clr();
  } 

  event void Timer.fired(){
    if(call Power.get()){
      call Power.clr();
    } else{
      call Leds.led2Toggle();
      call Power.set();
    }
    call Leds.led1Toggle();
    call Resource.request();
  }

  event void Resource.granted(){
    post readSerialTask();
  }

  task void readSerialTask(){
    call CSN.clr();
    call SpiByte.write(S_RDID);
    call SpiPacket.send(NULL, id_buf, ID_LEN);
  }

  async event void SpiPacket.sendDone( uint8_t* txBuf, uint8_t* rxBuf, uint16_t len,
                             error_t error ){
    call CSN.set();
    call Resource.release();
    post reportIDTask();
  }

  task void reportIDTask(){
    uint8_t i;
    if(call Power.get()){
      printf("1 ");
    } else{
      printf("0 ");
    }
    for (i=0; i < ID_LEN; i++){
      printf("%x", id_buf[i]);
    }
    printf("\n\r");
    memset(id_buf, 0, ID_LEN);
  }
}
