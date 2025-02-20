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

#ifndef PLATFORM_RF1A_CONFIGURE_H
#define PLATFORM_RF1A_CONFIGURE_H
#warning "using platform config from bacon"

#ifndef CC1101_DEF_CHANNEL 
#warning use default channel
#define CC1101_DEF_CHANNEL 255
#endif

#ifndef CC1101_DEF_RFPOWER 
#warning using default power
//-30 0x03 
//-12 0x25 
//-6 0x2d 
//0 0x8D 
//10 0xC3 
//max: 0xC0
#define CC1101_DEF_RFPOWER 0x8D
#endif

const rf1a_config_t rf1a_default_config = {
    iocfg2:  0x29,   // IOCFG2    GDO2 output pin configuration.
    //iocfg1 default from Rf1aConfigure.h 
    iocfg1:  0x2E,   //Set to RESET state.
    iocfg0:  0x06,   // IOCFG0D   GDO0 output pin configuration. Refer to SmartRF® Studio User Manual for detailed pseudo register explanation.
    fifothr: 0x07,   // FIFOTHR   RXFIFO and TXFIFO thresholds.
    //sync1 default from Rf1aConfigure.h 
    sync1:   0xd3,
    //sync0 default from Rf1aConfigure.h 
    sync1:   0x91,
    //TODO: this does get set in sw, right?
    pktlen:  0x3D,    // PKTLEN    Packet length.
    pktctrl1:0x04,   // PKTCTRL1  Packet automation control.
    pktctrl0:0x05,   // PKTCTRL0  Packet automation control.
    //TODO: this does get set in sw, right?
    addr:    0x00,   // ADDR      Device address.
    //TODO: this does get set in sw, right?
    CC1101_DEF_CHANNEL,    // CHANNR    Channel number.
    fsctrl1: 0x0C,   // FSCTRL1   Frequency synthesizer control.
    fsctrl0: 0x00,   // FSCTRL0   Frequency synthesizer control.
    freq2:   0x23,   // FREQ2     Frequency control word, high byte.
    freq1:   0x31,   // FREQ1     Frequency control word, middle byte.
    freq0:   0x3B,   // FREQ0     Frequency control word, low byte.
    mdmcfg4: 0x2D,   // MDMCFG4   Modem configuration.
    mdmcfg3: 0x3B,   // MDMCFG3   Modem configuration.
    mdmcfg2: 0x03,   // MDMCFG2   Modem configuration.
    mdmcfg1: 0x22,   // MDMCFG1   Modem configuration.
    mdmcfg0: 0xF8,   // MDMCFG0   Modem configuration.
    deviatn: 0x62,   // DEVIATN   Modem deviation setting (when FSK modulation is enabled).
    //mcsm2 default from Rf1aConfigure.h
    mcsm2:   0x07,
    //mcsm1 default from Rf1aConfigure.h
    mcsm1:   0x30,
    mcsm0:   0x10,   // MCSM0     Main Radio Control State Machine configuration.
    foccfg:  0x1D,   // FOCCFG    Frequency Offset Compensation Configuration.
    bscfg:   0x1C,   // BSCFG     Bit synchronization Configuration.
    agcctrl2:0xC7,   // AGCCTRL2  AGC control.
    agcctrl1:0x00,   // AGCCTRL1  AGC control.
    agcctrl0:0xB0,   // AGCCTRL0  AGC control.
    //worevt1 default from Rf1aConfigure.h
    worevt1: 0x80,
    //worevt0 default from Rf1aConfigure.h
    worevt0: 0x00,
    //worctrl default from Rf1aConfigure.h
    worctrl: 0xf0,
    frend1:  0xB6,   // FREND1    Front end RX configuration.
    frend0:  0x10,   // FREND0    Front end TX configuration.
    fscal3:  0xEA,   // FSCAL3    Frequency synthesizer calibration.
    fscal2:  0x2A,   // FSCAL2    Frequency synthesizer calibration.
    fscal1:  0x00,   // FSCAL1    Frequency synthesizer calibration.
    fscal0:  0x1F,   // FSCAL0    Frequency synthesizer calibration.
    //_rcctrl1: reserved, skipped in Rf1aConfigure.h
    //_rcctrl0: reserved, skipped in Rf1aConfigure.h
    fstest:  0x59,   // FSTEST    Frequency synthesizer calibration.
    //ptest: reserved, skipped in Rf1aConfigure.h
    //agctest: reserved, skipped in Rf1aConfigure.h
    test2:   0x88,   // TEST2     Various test settings.
    test1:   0x31,   // TEST1     Various test settings.
    test0:   0x09,   // TEST0     Various test settings.
    //patable (just patable0 is used), default from Rf1aConfigure.h
    patable: {CC1101_DEF_RFPOWER},
  };
#endif
