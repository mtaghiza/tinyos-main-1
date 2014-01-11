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

/**
 * InternalFlashC.nc - Internal flash implementation for msp430x2xxx
 * series. This family has 4 64-byte segments:
 *  0x1000 - 0x103f  D
 *  0x1040 - 0x107f  C
 *  0x1080 - 0x10bf  B
 *  0x10c0 - 0x10ff  A
 * 
 * Segment A is locked independently of the other segments, but this
 * implementation *does not* give it any special attention otherwise.
 * 
 * This module provides access to a configurable set of the segments
 * (e.g. A-D, A-B, C-D). 
 *
 * Addresses must be between 0 and 63 (0x3f). The highest order byte
 * of each segment is reserved for version tracking (though only the
 * high order byte in the first segment is used for this purpose).
 * When new data is written, the oldest segment is erased and the data
 * is stored there. The current segment number is updated after an
 * erase/write and is about as atomic as an operation can get, so this
 * should prevent data loss if a failure occurs in the middle of an
 * operation.
 *
 * The highest order byte of the first segment in use is an
 * inverse-unary number that indicates which segment should be written
 * to next. We can flip bits from 1 to 0 without doing a segment
 * erase, so we can increment this field freely.  This lets us
 * identify the version with a single flash read/lookup instead of
 * having to search through versions on each page and doing
 * comparisons.
 *
 * 0xffff = 0: "segment A erased"  -> write A, read D 
 * 0xfffe = 1: "segment A written" -> write B, read A 
 * 0xfffc = 2: "segment B written" -> write C, read B 
 * 0xfff8 = 3: "segment C written" -> write D, read C 
 * 0xfff0 = 4: "segment D written" -> write A, read D (4%numSegments == 0)
 *
 * @author Doug Carlson <carlson@cs.jhu.edu>
 */

#include "InternalFlash.h"
#include "InternalFlashFunctions.h"

generic module InternalFlashx2xxC (uint16_t IFLASH_START, uint8_t IFLASH_NUM_SEGMENTS){
  provides interface InternalFlash;
}

implementation {
  volatile uint8_t* IFLASH_NEXT = (uint8_t*) (IFLASH_START + (IFLASH_SEGMENT_SIZE * IFLASH_NUM_SEGMENTS) -1);

  uint8_t fromInverseUnary(uint8_t iu){
    uint8_t ret = 0;

    iu ^= 0xFF;
    while (iu){
      ret += 1;
      iu = (iu >> 1);
    }
    return ret;
  }

  uint8_t incrementInverseUnary(uint8_t iu){
    return (iu - 1) & iu;
  }

  int8_t getNextSegmentIndex(){
    return fromInverseUnary(*IFLASH_NEXT) % IFLASH_NUM_SEGMENTS;
  }

  //nb: segment A = segment 0 = TOP of flash
  uint8_t* getNextSegmentStart(){
    uint8_t index = (IFLASH_NUM_SEGMENTS - getNextSegmentIndex() - 1)%IFLASH_NUM_SEGMENTS;
    return (uint8_t*)(IFLASH_START + (index * IFLASH_SEGMENT_SIZE));
  }

  uint8_t* getCurrentSegmentStart(){
    uint8_t index = (IFLASH_NUM_SEGMENTS - getNextSegmentIndex() )%IFLASH_NUM_SEGMENTS;
    return (uint8_t*)(IFLASH_START + (index * IFLASH_SEGMENT_SIZE));
  }

  void incrementSegmentIndex(){
    unlockInternalFlash(IFLASH_NEXT);
    *IFLASH_NEXT = incrementInverseUnary(*IFLASH_NEXT);
    lockInternalFlash(IFLASH_NEXT);
  }

  command error_t InternalFlash.write(void* addr, void* buf, uint16_t size) {
    volatile uint8_t* targetSegmentStart;
    uint8_t wdState;
    
    if ((uint16_t)addr + size > IFLASH_SEGMENT_SIZE - 1){
      return ESIZE;
    }
    targetSegmentStart = getNextSegmentStart();
//    printf("InternalFlash: write to %p\n\r", targetSegmentStart);
    //pause watchdog
    wdState = WDTCTL & 0x00ff;
    WDTCTL = WDTPW + WDTHOLD;

    unlockInternalFlash(targetSegmentStart);

    //erase the target segment
    FCTL1 = FWKEY + ERASE;
    *targetSegmentStart = 0;

    //write to it
    FCTL1 = FWKEY + WRT;
    memcpy((void*)((uint16_t)addr + targetSegmentStart), buf, size);

    incrementSegmentIndex();

    //disable writes/erases
    FCTL1 = FWKEY;

    lockInternalFlash(targetSegmentStart);
    //restore watchdog settings
    WDTCTL = WDTPW + wdState;
    return SUCCESS;
  }

  command error_t InternalFlash.read(void* addr, void* buf, uint16_t size) {
    void* targetSegmentStart = (void*) getCurrentSegmentStart();

    if ((size + (uint16_t)addr) > (IFLASH_SEGMENT_SIZE - 1 )){
      return ESIZE;
    }
//    printf("InternalFlash: read from %p\n\r", targetSegmentStart);
    addr = (void*)((uint16_t)targetSegmentStart + (uint16_t)addr);

    //bingo-bango
    memcpy(buf, addr, size);
    return SUCCESS;
  }

}
