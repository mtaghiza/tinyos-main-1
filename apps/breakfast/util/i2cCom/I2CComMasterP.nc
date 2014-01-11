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


 #include "I2CCom.h"

module I2CComMasterP{
  provides interface I2CComMaster[uint8_t clientId];
  uses interface I2CPacket<TI2CBasicAddr>;
  uses interface Resource;
} implementation {
  norace i2c_message_t* msg;
  
  enum {
    CLIENT_NONE= 0xFF,
  };

  uint8_t curClient = CLIENT_NONE;

  enum {
    S_WRITE_REQUESTED = 0x01,
    S_WRITING = 0x02,
    S_READ_REQUESTED = 0x03,
    S_SEEKING = 0x04,
    S_READING = 0x05,
    S_IDLE = 0x06,
  };

  uint8_t state;
  norace error_t signalError;
  i2c_message_t* msg;

  task void signalSendDone();
  task void signalReceiveDone();
  void release();
  task void read();

  command void* I2CComMaster.getPayload[uint8_t client](i2c_message_t* msg_){
    return &msg_->body.buf;
  }

  bool acquire(uint8_t client){
    if (curClient == CLIENT_NONE){
      curClient = client;
    }
    return (client == curClient);
  }

  command error_t I2CComMaster.send[uint8_t client](uint16_t slaveAddr,
      i2c_message_t* msg_, uint8_t payloadLen){
    if (acquire(client)){
      error_t ret = call Resource.request();
      if ( ret == SUCCESS ){
        msg = msg_;
        msg->body.header.slaveAddr = slaveAddr;
        msg->body.header.clientId = client;
        msg->body.header.len = payloadLen + sizeof(i2c_message_header_t);
        state = S_WRITE_REQUESTED;
      } else{
        release();
      }
      return ret;
    } else {
      return ERETRY;
    }
  }

  task void write(){
    error_t error;
    error = call I2CPacket.write(I2C_START|I2C_STOP,
      msg->body.header.slaveAddr, 
      msg->body.header.len, 
      (uint8_t*)msg->buf); 
    if (error != SUCCESS){
      signalError = error;
      post signalSendDone();
    } else {
      state = S_WRITING;
    }
  }

  async event void I2CPacket.writeDone(error_t error, uint16_t addr,
      uint8_t length, uint8_t* data){
    signalError = error;
    msg->body.header.len = length;
    post signalSendDone();
  }

  task void signalSendDone(){
    uint8_t toSignal = curClient;
    release();
    signal I2CComMaster.sendDone[toSignal](signalError, msg);
  }

  void release(){
    atomic{
      call Resource.release();
      state = S_IDLE;
    }
    curClient = CLIENT_NONE;
  }

  event void Resource.granted(){
    switch (state){
      case S_WRITE_REQUESTED:
        state = S_WRITING;
        post write();
        break;
      case S_READ_REQUESTED:
        state = S_READING;
        post read();
      default:
        break;
    }
  }

  command error_t I2CComMaster.receive[uint8_t client](uint16_t slaveAddr, i2c_message_t*
  msg_, uint8_t len){
    if (acquire(client)){
      error_t ret = call Resource.request();
      if (ret == SUCCESS){
        msg = msg_;
        msg->body.header.slaveAddr = slaveAddr;
        msg->body.header.clientId = client;
        //Reading from slave: DOES NOT get header! just the body. see
        //  note in I2CComSlaveMultiP.
        msg->body.header.len = len;
        state = S_READ_REQUESTED;
      }else {
        release();
      }
      return ret;
    }else{
      return ERETRY;
    }
  }

  task void read(){
    signalError = call I2CPacket.read(I2C_START|I2C_STOP,
      msg->body.header.slaveAddr, msg->body.header.len, (uint8_t*)msg->body.buf);
    if (signalError == SUCCESS){
      state = S_READING;
    } else {
      // no bytes read.
      msg->body.header.len = 0;
      post signalReceiveDone();
    }
  }

  task void signalReceiveDone(){
    uint8_t toSignal = curClient;
    release();
    signal I2CComMaster.receiveDone[toSignal](signalError, msg);
  }

  async event void I2CPacket.readDone(error_t error, uint16_t addr,
      uint8_t length, uint8_t* data){
    msg->body.header.len = length;
    signalError = error;
    post signalReceiveDone();
  }

  default event void I2CComMaster.sendDone[uint8_t client](error_t error, i2c_message_t* msg_){
  }
  default event void I2CComMaster.receiveDone[uint8_t client](error_t error, i2c_message_t* msg_){}

}
