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

#ifndef INTERNAL_FLASH_FUNCTIONS_H
#define INTERNAL_FLASH_FUNCTIONS_H

//unlock: writing 1 to LOCKA *toggles* it, it doesn't set it.
//Writing 0 has no effect. SO, we want to write 1 if the bit is
//already set
//We additionally have to lock/unlock the entire information memory 
void unlockInternalFlash(volatile void* ptr){
  //clear FCTL4.LOCKINFO
  FCTL4 = FWPW + (FCTL4_L  &~ LOCKINFO);
  if ( ptr >= IFLASH_A_START && ptr <= IFLASH_A_END){
    FCTL3 = FWKEY + (FCTL3_L & LOCKA);
  } else {
    FCTL3 = FWKEY;
  }
}

//lock: LOCKA & (FCTL3 ^ LOCKA) = 0 if already locked, 1 if not
void lockInternalFlash(volatile void* ptr){
  if ( ptr >= IFLASH_A_START && ptr <= IFLASH_A_END){
    FCTL3 = FWKEY + LOCK + (LOCKA & (FCTL3_L ^ LOCKA));
  } else {
    FCTL3 = FWKEY + LOCK;
  }
  FCTL4 = FWPW + (FCTL4_L  | LOCKINFO);
}

#endif

