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
 * This configuration uses segments C and D only (leaving segment A
 * for a specialized configuration that treats it differently).
 *
 * Addresses must be between 0 and 63 (0x3f). The highest order byte
 * of each segment is reserved for version tracking (though only
 * 0x10FF is used for this purpose).  When new data is written, the
 * oldest segment is erased and the data is stored there. The current
 * segment number is updated after an erase/write and is about as
 * atomic as an operation can get, so this should prevent data loss if
 * a failure occurs in the middle of an operation.
 * 
 *
 * @author Doug Carlson <carlson@cs.jhu.edu>
 */

#include "InternalFlash.h"

configuration InternalFlashC{
  provides interface InternalFlash;
}
implementation {
  components new InternalFlashx2xxC((uint16_t)IFLASH_D_START, 2);
  InternalFlash = InternalFlashx2xxC;
}
