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

#ifndef I2C_ADCREADER_H
#define I2C_ADCREADER_H

#include "Msp430Adc12.h"

#define I2C_COM_CLIENT_ID_ADCREADER 0x01
#define ADC_READER_CMD_SAMPLE 0x0c

//number of samples to take for each config: median is returned
#ifndef ADC_NUM_SAMPLES
#define ADC_NUM_SAMPLES 5
#endif

//8 external, (Vcc-Vss)/2, temp. limited to 9 due to sizing mistake in toast
//binary
#ifndef ADC_NUM_CHANNELS
#define ADC_NUM_CHANNELS 9
#endif

#if ADC_NUM_CHANNELS > 9
#ifndef SUPPRESS_ADC_OVERFLOW_WARNING
//OK, due to a stupid mistake, there is only space for 8 data channels on
//the toast boards programmed by elektromont. Happily, as long as the
//last in the sequence is INPUT_CHANNEL_NONE, we won't overflow any
//buffers.
#warning "size of adc-read command exceeds elektromont toast buffer size! ADC_NUM_CHANNELS should be defined to be <= 9 to prevent overflows. Suppress this warning by defining SUPPRESS_ADC_OVERFLOW_WARNING."
#endif
#endif

//built-in delay required for slave to configure channel/set up
//measurement (in binary ms)
#ifndef CHANNEL_DELAY
#define CHANNEL_DELAY 10
#endif

#define ADC_TOTAL_SAMPLES ADC_NUM_CHANNELS * ADC_READER_MAX_SAMPLES_PER_CHANNEL

//see Msp430Adc12SingleChannel.nc for details: these get passed
//  straight through to that interface.
//  delayMS is used to instruct the reader that it should wait for
//  some timeout after turning on sensors but before starting the ADC
//  module (e.g. so that the master can enter LPM, or so that sensors
//  can warm up).
typedef struct adc_reader_config_t {
  uint32_t delayMS;
  uint16_t samplePeriod;
  msp430adc12_channel_config_t config;
} adc_reader_config_t;

//a packet consists of a set of these configs: up to 1 per sensor
//  (plus one for input voltage and one for internal temp)
// this way, we only have one sensor on at a time, and we can specify
// for each sensor how it needs to be warmed up/how many times it
// should get sampled. 
typedef struct adc_reader_pkt_t{
  uint8_t cmd;
  adc_reader_config_t cfg[ADC_NUM_CHANNELS];
} __attribute__((__packed__)) adc_reader_pkt_t;


typedef nx_struct adc_sample_t {
  nx_uint8_t inputChannel;
  nx_uint32_t sampleTime;
  nx_uint16_t sample;
} adc_sample_t;

typedef nx_struct adc_response_t {
  adc_sample_t samples[ADC_NUM_CHANNELS];
} adc_response_t;

#endif
