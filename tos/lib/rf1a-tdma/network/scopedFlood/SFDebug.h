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

#ifndef SF_DEBUG_H
#define SF_DEBUG_H

#if DEBUG_SF_TESTBED_AW == 1
#define printf_SF_TESTBED_AW(...) printf(__VA_ARGS__)
#else
#define printf_SF_TESTBED_AW(...)
#endif

#if DEBUG_SF_TESTBED_PR == 1
#define printf_SF_TESTBED_PR(...) printf(__VA_ARGS__)
#else
#define printf_SF_TESTBED_PR(...)
#endif

#if DEBUG_SF_TESTBED == 1
#define printf_SF_TESTBED(...) printf(__VA_ARGS__)
#else
#define printf_SF_TESTBED(...)
#endif

#if DEBUG_SF_STATE == 1
#define printf_SF_STATE(...) printf(__VA_ARGS__)
#else
#define printf_SF_STATE(...)
#endif

#if DEBUG_SF_GP == 1
#define printf_SF_GP(...) printf(__VA_ARGS__)
#else
#define printf_SF_GP(...)
#endif

#if DEBUG_SF_RX == 1
#define printf_SF_RX(...) printf(__VA_ARGS__)
#else
#define printf_SF_RX(...)
#endif

#if DEBUG_SF_SV == 1
#define printf_SF_SV(...) printf(__VA_ARGS__)
#else
#define printf_SF_SV(...) 
#endif

#if DEBUG_SF_ROUTE == 1
#define printf_SF_ROUTE(...) printf(__VA_ARGS__)
#else
#define printf_SF_ROUTE(...) 
#endif

#if DEBUG_SF_CLEARTIME == 1
#define printf_SF_CLEARTIME(...) printf(__VA_ARGS__)
#else
#define printf_SF_CLEARTIME(...) 
#endif

#if defined PORT_SF_GPO && defined PIN_SF_GPO
#define SF_GPO_TOGGLE_PIN TDMA_TOGGLE_PIN(PORT_SF_GPO, PIN_SF_GPO)
#define SF_GPO_CLEAR_PIN TDMA_CLEAR_PIN(PORT_SF_GPO, PIN_SF_GPO)
#define SF_GPO_SET_PIN TDMA_SET_PIN(PORT_SF_GPO, PIN_SF_GPO)
#else 
#define SF_GPO_TOGGLE_PIN 
#define SF_GPO_CLEAR_PIN 
#define SF_GPO_SET_PIN 
#endif

#if defined PORT_SF_GPF && defined PIN_SF_GPF
#define SF_GPF_TOGGLE_PIN TDMA_TOGGLE_PIN(PORT_SF_GPF, PIN_SF_GPF)
#define SF_GPF_CLEAR_PIN TDMA_CLEAR_PIN(PORT_SF_GPF, PIN_SF_GPF)
#define SF_GPF_SET_PIN TDMA_SET_PIN(PORT_SF_GPF, PIN_SF_GPF)
#else 
#define SF_GPF_TOGGLE_PIN 
#define SF_GPF_CLEAR_PIN 
#define SF_GPF_SET_PIN 
#endif


#endif
