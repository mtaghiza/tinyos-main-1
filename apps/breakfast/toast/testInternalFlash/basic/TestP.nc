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

#define DEST_ADDR (uint8_t*)0x1000
module TestP{
  uses interface Boot;
} implementation {
  uint8_t lValues[] = {
    0xff,
    0x7f,
    0x3f,
    0x1f,
    0x0f,
    0x07,
    0x03,
    0x01,
    0x00
  };

  uint8_t rValues[] = {
    0xff,
    0xfe,
    0xfc,
    0xf8,
    0xf0,
    0xe0,
    0xc0,
    0x80,
    0x00
  };

  event void Boot.booted(){
    volatile uint8_t* dest = DEST_ADDR;
    int8_t k;
    printf("Booted\n\r");
    WDTCTL = WDTPW + WDTHOLD;
    //set up timing generator (mclk/12 puts it in the right range)
    FCTL2 = FWKEY + FSSEL_1 + 11;
    //unlock
    FCTL3 = FWKEY; 

    printf("Initial: %x\n\r", *dest);

    //erase the target segment
    FCTL1 = FWKEY + ERASE;
    *dest = 0;
    printf("Erased: %x\n\r", *dest);

    for(k = 0; k < 8; k++){
      FCTL1 = FWKEY + WRT;
      *dest = lValues[k];
      FCTL1 = FWKEY;
      printf("Left erase %d: %x\n\r", k, *dest);
    }

    FCTL1 = FWKEY + ERASE;
    *dest = 0;
    printf("Erased: %x\n\r", *dest);

    for(k = 0; k < 8; k++){
      FCTL1 = FWKEY + WRT;
      *dest = rValues[k];
      FCTL1 = FWKEY;
      printf("Right erase %d: %x\n\r", k, *dest);
    }
    //lock
    FCTL3 = FWKEY + LOCK + LOCKA; 
  }
}
