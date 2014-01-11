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
#include "decodeError.h"

module TestP{
  uses interface Boot;
  uses interface Timer<TMilli>;
  uses interface InternalFlash;
  uses interface InternalFlash as InternalFlashA;

} implementation {
  uint8_t counter;
  uint8_t counterA = 10;
  event void Boot.booted(){
    printf("Booted\n\r");
    call Timer.startPeriodic(1024);
  }

  #define DEST_ADDR ((uint8_t*)0x00)
  event void Timer.fired(){
    uint8_t check = 0;
    error_t error = FAIL;
    error = call InternalFlash.write(DEST_ADDR, &counter, 1);
    printf("Wrote %d to %p (STD): %s\n\r", counter, DEST_ADDR, decodeError(error));
    error = call InternalFlashA.write(DEST_ADDR, &counterA, 1);
    printf("Wrote %d to %p (A):   %s\n\r", counterA, DEST_ADDR, decodeError(error));

    error = call InternalFlash.read(DEST_ADDR, &check, 1);
    printf("Read %d from %p (STD): %s\n\r", check, DEST_ADDR, decodeError(error));
    error = call InternalFlashA.read(DEST_ADDR, &check, 1);
    printf("Read %d from %p (A):   %s\n\r", check, DEST_ADDR, decodeError(error));
    counter++;
    counterA++;
    printf("\n\r----\n\r");
    if (counter > 4){
      printf("Stopping\n\r");
      call Timer.stop();
    }
  }

}
