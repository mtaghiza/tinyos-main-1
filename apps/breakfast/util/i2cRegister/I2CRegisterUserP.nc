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

#include "I2CRegisterUser.h"

generic module I2CRegisterUserP(uint8_t clientId){
  provides interface I2CRegisterUser;
  uses interface I2CPacket<TI2CBasicAddr>;
  uses interface Resource;
} implementation {

  enum {
    S_WRITE_REQUESTED = 0x01,
    S_WRITING = 0x02,
    S_READ_REQUESTED = 0x03,
    S_SEEKING = 0x04,
    S_READING = 0x05,
    S_IDLE = 0x06,
  };

  norace uint8_t state;
  norace error_t signalError;
  norace register_packet_t* pkt;

  task void signalWriteDone();
  task void signalReadDone();
  task void readTask();
  task void write();

  void release(){
    atomic{
      call Resource.release();
      state = S_IDLE;
    }
  }

  command error_t I2CRegisterUser.write(uint16_t slaveAddr_, uint8_t pos,
      register_packet_t* pkt_, uint8_t len_){
    error_t ret = call Resource.request();
    printf("%s: \n\r", __FUNCTION__);
    if ( ret == SUCCESS ){
      pkt = pkt_;
      pkt->header.clientId = clientId;
      pkt->header.pos = pos;
      pkt->footer.len = len_;
      pkt->footer.slaveAddr = slaveAddr_;
      state = S_WRITE_REQUESTED;
    } 
    return ret;
  }

  task void write(){
    //footer.len is just data length, add in header
    error_t error = call I2CPacket.write(I2C_START|I2C_STOP,
      pkt->footer.slaveAddr, 
      pkt->footer.len + sizeof(register_packet_header_t), 
      (uint8_t*) pkt); 
    if (error != SUCCESS){
      signalError = error;
      post signalWriteDone();
    }
  }

  task void seek(){
    //just write the client ID/position
    error_t error = call I2CPacket.write(I2C_START,
      pkt->footer.slaveAddr, sizeof(register_packet_header_t),
      (uint8_t*)pkt);
    if (error != SUCCESS){
      signalError = error;
      post signalReadDone();
    }
  }

  event void Resource.granted(){
    printf("%s: \n\r", __FUNCTION__);
    switch (state){
      case S_WRITE_REQUESTED:
        state = S_WRITING;
        post write();
        break;
      case S_READ_REQUESTED:
        state = S_SEEKING;
        post seek();
        break;
      default:
        break;
    }
  }

  task void signalWriteDone(){
    release();
    signal I2CRegisterUser.writeDone(signalError, pkt->footer.slaveAddr,
      pkt->header.pos, pkt->footer.len, pkt);
  }

  task void signalReadDone(){
    release();
    signal I2CRegisterUser.readDone(signalError, pkt->footer.slaveAddr,
      pkt->header.pos, pkt, pkt->footer.len);
  }

  async event void I2CPacket.writeDone(error_t error, uint16_t addr,
      uint8_t length, uint8_t* data){
    switch (state){
      case S_WRITING:
        signalError = error;
        pkt->footer.len = length;
        post signalWriteDone();
        break;
      case S_SEEKING:
        if (error == SUCCESS){
          post readTask();
        } else {
          signalError = error;
          //indicate "no bytes read" since we failed to seek
          pkt->footer.len = 0;
          post signalReadDone();
        }
        break;
    }
  }

  task void readTask(){
    //read into pkt->data 
    signalError = call I2CPacket.read(I2C_RESTART|I2C_STOP,
      pkt->footer.slaveAddr, pkt->footer.len, pkt->data);
    if (signalError == SUCCESS){
      state = S_READING;
    } else {
      // no bytes read.
      pkt->footer.len = 0;
      post signalReadDone();
    }
  }

  command error_t I2CRegisterUser.read(uint16_t slaveAddr, uint8_t pos,
      register_packet_t* pkt_, uint8_t len){
    error_t ret = call Resource.request();
    if (ret == SUCCESS){
      pkt = pkt_;
      pkt->header.clientId = clientId;
      pkt->header.pos = pos;
      pkt->footer.len = len;
      pkt->footer.slaveAddr = slaveAddr;
      state = S_READ_REQUESTED;
    } 
    return ret;
  }

  async event void I2CPacket.readDone(error_t error, uint16_t addr,
      uint8_t length, uint8_t* data){
    pkt->footer.len = length;
    signalError = error;
    post signalReadDone();
  }


}
