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

/***************************************************************
 *  SmartRF Studio(tm) Export
 *
 *  Radio register settings specifed with C-code
 *  compatible #define statements.
 *
 ***************************************************************/

#ifndef SMARTRF_CC430_H
#define SMARTRF_CC430_H

#define SMARTRF_RADIO_CC430

#define SMARTRF_SETTING_FSCTRL1    0x06
#define SMARTRF_SETTING_FSCTRL0    0x00
#define SMARTRF_SETTING_FREQ2      0x22
#define SMARTRF_SETTING_FREQ1      0xB1
#define SMARTRF_SETTING_FREQ0      0x3B
#define SMARTRF_SETTING_MDMCFG4    0xC8
#define SMARTRF_SETTING_MDMCFG3    0x93
#define SMARTRF_SETTING_MDMCFG2    0x13
#define SMARTRF_SETTING_MDMCFG1    0x22
#define SMARTRF_SETTING_MDMCFG0    0xF8
#define SMARTRF_SETTING_CHANNR     0x0a
#define SMARTRF_SETTING_DEVIATN    0x34
#define SMARTRF_SETTING_FREND1     0x56
#define SMARTRF_SETTING_FREND0     0x10
#define SMARTRF_SETTING_MCSM0      0x10
#define SMARTRF_SETTING_FOCCFG     0x16
#define SMARTRF_SETTING_BSCFG      0x6C
#define SMARTRF_SETTING_AGCCTRL2   0x03
#define SMARTRF_SETTING_AGCCTRL1   0x40
#define SMARTRF_SETTING_AGCCTRL0   0x91
#if 0
/* Settings emitted by SmartRF Studio */
#define SMARTRF_SETTING_FSCAL3     0xE9
#define SMARTRF_SETTING_FSCAL2     0x2A
#define SMARTRF_SETTING_FSCAL1     0x00
#define SMARTRF_SETTING_FSCAL0     0x1F
#else
/* Settings observed in real world */
#define SMARTRF_SETTING_FSCAL3     0xEF
#define SMARTRF_SETTING_FSCAL2     0x2D
#define SMARTRF_SETTING_FSCAL1     0x25
#define SMARTRF_SETTING_FSCAL0     0x1F
#endif
#define SMARTRF_SETTING_FSTEST     0x59
#define SMARTRF_SETTING_TEST2      0x81
#define SMARTRF_SETTING_TEST1      0x35
#define SMARTRF_SETTING_TEST0      0x09
#define SMARTRF_SETTING_FIFOTHR    0x47
#define SMARTRF_SETTING_IOCFG2     0x2E
#define SMARTRF_SETTING_IOCFG0D    0x29
#define SMARTRF_SETTING_PKTCTRL1   0x04
#define SMARTRF_SETTING_PKTCTRL0   0x45
#define SMARTRF_SETTING_ADDR       0x00
#define SMARTRF_SETTING_PKTLEN     0xFF

/* TinyOS Custom Settings */

// CCA if RSSI < thr unless rx; RX stay in RX ; TX go to RX
#define SMARTRF_SETTING_MCSM1      0x3F

// Default power configuration
#define SMARTRF_SETTING_PATABLE0   0xC0

/** Minimum legal channel number */
#define RF1A_CHANNEL_MIN (10)
/** Maximum legal channel number */
#define RF1A_CHANNEL_MAX (19)

#endif

