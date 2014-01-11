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

module SamplerP{
  provides interface SplitControl;

  uses interface Resource;
  uses interface Msp430Adc12SingleChannel;
  uses interface Msp430Adc12Overflow;

  uses interface AdcConfigure<const msp430adc12_channel_config_t*>;

  provides interface Sampler;
} implementation {
  #ifndef BUFFER_SIZE
  #define BUFFER_SIZE 16
  #endif

  uint16_t bufferA[BUFFER_SIZE];
  uint16_t bufferB[BUFFER_SIZE];

  norace uint16_t* curBuf = bufferA;
  norace uint16_t* lastBuf = bufferB;

  bool stopSampling = FALSE;

  command error_t SplitControl.start(){
    return call Resource.request();
  }

  event void Resource.granted(){
    signal SplitControl.startDone(SUCCESS);
  }

  task void stopDoneTask(){
    signal SplitControl.stopDone(SUCCESS);
  }
  
  command error_t SplitControl.stop(){
    error_t err = call Resource.release();
    if (err == SUCCESS){
      post stopDoneTask();
    }
    return err;
  }

  task void reportData(){
    uint16_t* result = signal Sampler.burstDone(lastBuf);
    if (result == NULL){
      stopSampling = TRUE;
    } else { 
      stopSampling = FALSE;
      lastBuf = result;
    }
  }

  async event uint16_t * COUNT_NOK(numSamples) Msp430Adc12SingleChannel.multipleDataReady(uint16_t *COUNT(numSamples) buffer, uint16_t numSamples) {
    P1OUT ^= BIT1;
    if ( stopSampling){
      return NULL;
    }else{
      curBuf = lastBuf;
      lastBuf = buffer;
      post reportData();
      return curBuf;
    }
  }

  async event void Msp430Adc12Overflow.memOverflow(){
    printf("!memOverflow\r\n");
  }

  async event void Msp430Adc12Overflow.conversionTimeOverflow(){
    printf("!ctOverflow\r\n");
  }

  
  error_t configure(uint16_t sampleInterval){
    error_t error = call Msp430Adc12SingleChannel.configureMultipleRepeat(
      call AdcConfigure.getConfiguration(), curBuf, BUFFER_SIZE,
      sampleInterval);

    if (error != SUCCESS){
      printf("ConfigureMultiple: %s\r\n", decodeError(error));
    }
    return error;
  }

  command error_t Sampler.startSampling(uint16_t sampleInterval){
    error_t error = configure(sampleInterval);
    if (SUCCESS == error){
      error = call Msp430Adc12SingleChannel.getData();
      if (SUCCESS != error){
        printf("getData: %s\r\n", decodeError(error));
      }else{
        stopSampling = FALSE;
      }
    }
    return error;
  }

  async event error_t Msp430Adc12SingleChannel.singleDataReady(uint16_t data){
    printf("!singleDataReady\r\n");
    return SUCCESS;
  }

}
