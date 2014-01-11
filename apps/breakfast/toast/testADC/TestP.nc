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

#include "Msp430Adc12.h"
#include <stdio.h>

module TestP{
  uses interface Boot;
  uses interface Resource;
  uses interface Msp430Adc12SingleChannel;
  provides interface AdcConfigure<const msp430adc12_channel_config_t*>;
  uses interface Timer<TMilli>;
} implementation {
  const msp430adc12_channel_config_t config = {
    inch: INPUT_CHANNEL_A0,            // input channel 
    sref: REFERENCE_VREFplus_AVss,            // reference voltage 
    ref2_5v: REFVOLT_LEVEL_2_5,         // reference voltage level 
    adc12ssel: SHT_SOURCE_ADC12OSC,       // clock source sample-hold-time 
    adc12div: SHT_CLOCK_DIV_1, // clock divider sample-hold-time 
    sht: SAMPLE_HOLD_4_CYCLES,             // sample-hold-time
    sampcon_ssel: SAMPCON_SOURCE_TACLK,    // clock source sampcon signal 
    sampcon_id: SAMPCON_CLOCK_DIV_1,      // clock divider sampcon 
  };

  event void Boot.booted(){
    P4SEL &= ~(BIT3);
    P4OUT |= BIT3;
    P6SEL |= BIT0;
    P6DIR |= BIT0;
    call Timer.startOneShot(512);
  }

  event void Resource.granted(){
    call Msp430Adc12SingleChannel.configureSingle(&config);
    call Msp430Adc12SingleChannel.getData();
  }

  event void Timer.fired(){
    call Resource.request();
  }

  uint16_t lastSample;
 
  task void reportLastSample(){
    printf("DATA %x\n\r", lastSample);
    call Resource.release();
    call Timer.startOneShot(512);
  }

  async event error_t Msp430Adc12SingleChannel.singleDataReady(uint16_t data){
    lastSample = data;
    post reportLastSample();
    return SUCCESS;
  }

  async event uint16_t*
  Msp430Adc12SingleChannel.multipleDataReady(uint16_t* buffer, uint16_t numSamples){
  return buffer;
  }

  async command const msp430adc12_channel_config_t* AdcConfigure.getConfiguration(){
    return &config;
  }
}
