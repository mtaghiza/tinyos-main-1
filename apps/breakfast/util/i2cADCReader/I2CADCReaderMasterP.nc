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

#include "I2CADCReader.h"
module I2CADCReaderMasterP{
  provides interface I2CADCReaderMaster;
  uses interface I2CComMaster;
  uses interface Timer<TMilli>;
} implementation {
  uint16_t slave;
  i2c_message_t* cmdMsg;
  i2c_message_t responseMsg_internal;
  i2c_message_t* responseMsg = &responseMsg_internal;

  enum {
    S_IDLE = 0x00,
    S_BUSY = 0x80,
    S_WRITING = 0x01,
    S_WAITING = 0x02,
    S_READING = 0x04,
  };
  uint8_t state = S_IDLE;

  command adc_reader_pkt_t* I2CADCReaderMaster.getSettings(i2c_message_t* msg){
    return (adc_reader_pkt_t*)call I2CComMaster.getPayload(msg);
  }

  command adc_response_t* I2CADCReaderMaster.getResults(i2c_message_t* msg){
    return (adc_response_t*)call I2CComMaster.getPayload(msg);
  }

  command error_t I2CADCReaderMaster.sample(uint16_t slaveAddr,
      i2c_message_t* msg){
    error_t ret;
    adc_reader_pkt_t* settings;
    if (state & S_BUSY){
      return EBUSY;
    }
    cmdMsg = msg;
    settings = call I2CADCReaderMaster.getSettings(cmdMsg);
    settings->cmd = ADC_READER_CMD_SAMPLE;
    ret = call I2CComMaster.send(slaveAddr, cmdMsg, sizeof(adc_reader_pkt_t));
    if (ret == SUCCESS){
      state = (S_BUSY|S_WRITING);
    }
//    printf("I2C Send(%u): %x %p\r\n", sizeof(adc_reader_pkt_t), ret,
//      cmdMsg);
    return ret;
  }

  event void I2CComMaster.sendDone(error_t error, i2c_message_t* msg){
    uint8_t i;
    uint32_t delay = 0;
    adc_reader_pkt_t* settings = call I2CADCReaderMaster.getSettings(cmdMsg);
//    printf("I2C Send done: %x %p\r\n", error, msg);
    //TODO: verify msg==cmdMsg
    if (error == SUCCESS){
      for (i = 0; i< ADC_NUM_CHANNELS && settings->cfg[i].config.inch != INPUT_CHANNEL_NONE; i++){
        delay += settings->cfg[i].delayMS + CHANNEL_DELAY;
        //TODO: also get the sample/hold time numbers
      }
      call Timer.startOneShot(delay);
      state = S_BUSY | S_WAITING;
    } else {
      state = S_IDLE;
      responseMsg = signal I2CADCReaderMaster.sampleDone(error,
        cmdMsg->body.header.slaveAddr, cmdMsg, responseMsg, NULL);
    }
  }

  event void Timer.fired(){
    error_t error = call
    I2CComMaster.receive(cmdMsg->body.header.slaveAddr, responseMsg,
      sizeof(adc_response_t));
//    printf("I2C Receive: %x %p\r\n", error, responseMsg);
    if (error != SUCCESS){
      state = S_IDLE;
      responseMsg = signal I2CADCReaderMaster.sampleDone(error,
        cmdMsg->body.header.slaveAddr, cmdMsg, responseMsg,
        call I2CADCReaderMaster.getResults(responseMsg));
    } else {
      state = S_BUSY | S_READING;
    }
  }

  event void I2CComMaster.receiveDone(error_t error, i2c_message_t*
      rMsg){
//    printf("I2C ReceiveDone: %u %x %p %p %lu\r\n",
//      rMsg->body.header.len,
//      error, rMsg,
//      responseMsg, 
//      (call I2CADCReaderMaster.getResults(responseMsg))->samples[0].sampleTime);
    //TODO: verify rMsg == responseMsg
    state = S_IDLE;
    responseMsg = signal I2CADCReaderMaster.sampleDone(error,
      cmdMsg->body.header.slaveAddr, cmdMsg, responseMsg, 
      call I2CADCReaderMaster.getResults(responseMsg));
  }
}
