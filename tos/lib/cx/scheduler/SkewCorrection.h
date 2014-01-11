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

#ifndef SKEW_CORRECTION_H
#define SKEW_CORRECTION_H

#ifndef CX_USE_FP_SKEW_CORRECTION
#define CX_USE_FP_SKEW_CORRECTION 0
#endif

#ifndef TPF_DECIMAL_PLACES 
#define TPF_DECIMAL_PLACES 16L
#endif

//alpha is also fixed point.
#define FP_1 (1L << TPF_DECIMAL_PLACES)

#ifndef SKEW_EWMA_ALPHA_INVERSE
#define SKEW_EWMA_ALPHA_INVERSE 2
#endif

#define sfpMult(a, b) fpMult(a, b, TPF_DECIMAL_PLACES)
#define stoFP(a) toFP(a, TPF_DECIMAL_PLACES)
#define stoInt(a) toInt(a, TPF_DECIMAL_PLACES)

//50 ppm error over a 1024-tick frame ~= 0.05 ticks per frame
//MAX_VALID_TPF is ~0.0507
#define MAX_VALID_TPF ((FP_1 >> 5) + (FP_1 >> 6) + (FP_1 >> 8))

#endif
