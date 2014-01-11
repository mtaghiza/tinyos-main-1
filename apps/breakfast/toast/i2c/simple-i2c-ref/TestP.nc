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

module TestP{
  uses interface Boot;
  uses interface Leds;
  uses interface I2CPacket<TI2CBasicAddr> as I2CBasicAddr;
  uses interface Resource;
  uses interface ResourceRequested;
  uses interface StdControl as UartControl;
  uses interface Timer<TMilli>;
  uses interface GeneralIO as Pin0;
  uses interface GeneralIO as Pin1;
  uses interface GeneralIO as Pin2;
  uses interface GeneralIO as Pin3;
  provides interface Msp430I2CConfigure;
} implementation {

  enum{
    S_INIT     = 0,
    S_STARTING = 1,
    S_STARTED  = 2,
    S_WRITING  = 3,
    S_WRITTEN  = 4,
    S_READING  = 5,
    S_READ     = 6,
    S_ERROR    = 7,
    S_DONE     = 8,
  };

  uint8_t state = S_INIT;
  uint8_t i2c_length;
  uint8_t i2c_buffer[10];

  //7-bit address, 2LSB are from addr pins, the other 5 are from
  //  manufacturer
  //           MMM MMAA
  //---- ---- -100 1000
  uint16_t adg_addr=0x0048;

  uint16_t delay = 1;

  void setState(uint8_t s){
    state = s;
    P6OUT = ((P6OUT&0xf0) | state);
  }

  event void Boot.booted(){
    call Pin0.makeOutput();
    call Pin1.makeOutput();
    call Pin2.makeOutput();
    call Pin3.makeOutput();
    call Pin0.clr();
    call Pin1.clr();
    call Pin2.clr();
    call Pin3.clr();
    setState(S_STARTING);
    call Resource.request();
  }

  event void Resource.granted(){
    setState(S_STARTED);
    call Timer.startOneShot(delay);
  }

  event void Timer.fired(){
    error_t err;
    switch(state){

      case S_STARTED:
        err = call I2CBasicAddr.write(I2C_START|I2C_STOP, adg_addr, i2c_length, i2c_buffer);
        if (err == SUCCESS){
          setState(S_WRITING);
        } else {
          call Leds.set(err);
          setState(S_ERROR);
        }
        break;

      case S_WRITTEN:
        err = call I2CBasicAddr.read(I2C_START|I2C_STOP, adg_addr, i2c_length, i2c_buffer);
        if (err == SUCCESS){
          setState(S_READING);
        } else {
          call Leds.set(err);
          setState(S_ERROR);
        }
        break;

      case S_READ:
        //fall-through
      case S_DONE:
        setState(S_DONE);
        call Leds.set(call Leds.get() ^ 7);
        call Timer.startOneShot(delay);
        break;

    }
  }


  
  async event void I2CBasicAddr.writeDone(error_t error, 
      uint16_t addr, uint8_t length, uint8_t* data){
    if (error == SUCCESS){
      setState(S_WRITTEN);
      call Timer.startOneShot(delay);
    } else {
      setState(S_ERROR);
      call Leds.set(error);
    }
    return;
  }

  async event void I2CBasicAddr.readDone(error_t error, uint16_t addr,
      uint8_t length, uint8_t* data){
    if (error == SUCCESS){
      setState(S_READ);
      call Timer.startOneShot(delay);
    } else {
      setState(S_ERROR);
      call Leds.set(error);
    }
    return;
  }

  async command msp430_i2c_union_config_t* Msp430I2CConfigure.getConfig(){
    return &msp430_i2c_default_config;
  }


  async event void ResourceRequested.requested(){ }
  async event void ResourceRequested.immediateRequested(){ }

}
