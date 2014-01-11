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

#ifndef STATE_TIMING_DEBUG_H
#define STATE_TIMING_DEBUG_H

#if defined PORT_STATE_TIMING_CAP && defined PIN_STATE_TIMING_CAP 
#define STATE_TIMING_CAP_TOGGLE_PIN TDMA_TOGGLE_PIN(PORT_STATE_TIMING_CAP, PIN_STATE_TIMING_CAP)
#define STATE_TIMING_CAP_CLEAR_PIN TDMA_CLEAR_PIN(PORT_STATE_TIMING_CAP, PIN_STATE_TIMING_CAP)
#define STATE_TIMING_CAP_SET_PIN TDMA_SET_PIN(PORT_STATE_TIMING_CAP, PIN_STATE_TIMING_CAP)
#else 
#define STATE_TIMING_CAP_TOGGLE_PIN 
#define STATE_TIMING_CAP_CLEAR_PIN 
#define STATE_TIMING_CAP_SET_PIN 
#endif

#if defined PORT_STATE_TIMING_TX && defined PIN_STATE_TIMING_TX 
#define STATE_TIMING_TX_TOGGLE_PIN TDMA_TOGGLE_PIN(PORT_STATE_TIMING_TX, PIN_STATE_TIMING_TX)
#define STATE_TIMING_TX_CLEAR_PIN TDMA_CLEAR_PIN(PORT_STATE_TIMING_TX, PIN_STATE_TIMING_TX)
#define STATE_TIMING_TX_SET_PIN TDMA_SET_PIN(PORT_STATE_TIMING_TX, PIN_STATE_TIMING_TX)
#else 
#define STATE_TIMING_TX_TOGGLE_PIN 
#define STATE_TIMING_TX_CLEAR_PIN 
#define STATE_TIMING_TX_SET_PIN 
#endif

#if defined PORT_SW_CAP && defined PIN_SW_CAP 
#define SW_CAP_TOGGLE_PIN TDMA_TOGGLE_PIN(PORT_SW_CAP, PIN_SW_CAP)
#define SW_CAP_CLEAR_PIN TDMA_CLEAR_PIN(PORT_SW_CAP, PIN_SW_CAP)
#define SW_CAP_SET_PIN TDMA_SET_PIN(PORT_SW_CAP, PIN_SW_CAP)
#else 
#define SW_CAP_TOGGLE_PIN 
#define SW_CAP_CLEAR_PIN 
#define SW_CAP_SET_PIN 
#endif

#if defined PORT_SW_OF && defined PIN_SW_OF 
#define SW_OF_TOGGLE_PIN TDMA_TOGGLE_PIN(PORT_SW_OF, PIN_SW_OF)
#define SW_OF_CLEAR_PIN TDMA_CLEAR_PIN(PORT_SW_OF, PIN_SW_OF)
#define SW_OF_SET_PIN TDMA_SET_PIN(PORT_SW_OF, PIN_SW_OF)
#else 
#define SW_OF_TOGGLE_PIN 
#define SW_OF_CLEAR_PIN 
#define SW_OF_SET_PIN 
#endif

#if defined PORT_SW_OFP && defined PIN_SW_OFP 
#define SW_OFP_TOGGLE_PIN TDMA_TOGGLE_PIN(PORT_SW_OFP, PIN_SW_OFP)
#define SW_OFP_CLEAR_PIN TDMA_CLEAR_PIN(PORT_SW_OFP, PIN_SW_OFP)
#define SW_OFP_SET_PIN TDMA_SET_PIN(PORT_SW_OFP, PIN_SW_OFP)
#else 
#define SW_OFP_TOGGLE_PIN 
#define SW_OFP_CLEAR_PIN 
#define SW_OFP_SET_PIN 
#endif

#ifdef DEBUG_SW_CAPTURE
#define printf_SW_CAPTURE(...) printf(__VA_ARGS__)
#else
#define printf_SW_CAPTURE(...) 
#endif



#endif
