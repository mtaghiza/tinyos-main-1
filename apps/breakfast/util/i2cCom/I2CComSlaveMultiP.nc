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
module I2CComSlaveMultiP {
  provides interface I2CComSlave[uint8_t clientId];
  provides interface SplitControl;
  uses interface Resource;
  uses interface I2CSlave;
} implementation {

  norace uint8_t transCount;

  bool isGC;
  norace bool isReceive = FALSE;

  norace bool isPaused = FALSE;
  norace bool eventPending = FALSE;
  
  i2c_message_t txPkt_;
  i2c_message_t rxPkt_;

  norace i2c_message_t* txPkt = &txPkt_;
  norace i2c_message_t* rxPkt = &rxPkt_;

  enum{
    I2C_COM_SLAVE_INVALID = 0xff,
  };

  norace uint8_t lastClient = I2C_COM_SLAVE_INVALID;

  void transmit();
  void receive();

  async command void* I2CComSlave.getPayload[uint8_t clientId](i2c_message_t* msg){
    return & msg->body.buf;
  }

  async command error_t I2CComSlave.pause[uint8_t clientId](){
    if (clientId == lastClient){
      if (isPaused){
        return EALREADY;
      } else {
        isPaused = TRUE;
        return SUCCESS;
      }
    } else {
      printf("not active client\n\r");
      return EBUSY;
    }
  }

  async command error_t I2CComSlave.unpause[uint8_t clientId](){
    if (clientId == lastClient){
      if (isPaused){
        isPaused = FALSE;
        if (eventPending){
          if (isReceive){
            receive();
          } else {
            transmit();
          }
        } 
        return SUCCESS;
      } else {
        printf("not paused\n\r");
        return EALREADY;
      }
    } else {
      printf("Active Client wrong\n\r");
      return EBUSY;
    }
  }

  command error_t SplitControl.start(){
    return call Resource.request();
  }

  task void stopDone(){
    signal SplitControl.stopDone(SUCCESS);
  }

  command error_t SplitControl.stop(){
    error_t ret = call Resource.release();
    if (ret == SUCCESS){
      post stopDone();
    }
    return ret;
  }

  event void Resource.granted(){
    signal SplitControl.startDone(SUCCESS);
  }

  //Note: slave receive gets entire packet (including header). Slave
  //  transmit, however, only sends back the body. This is because:
  //  a. slave can't know len (up to master)
  //  b. at the master, only a single client could be using I2c, so
  //     there's no need for multiplexing
  //  c. "slaveAddr" field is meaningless in this context.
  //  d. less bytes, so faster
  void receive(){
    eventPending = FALSE;
    rxPkt->buf[transCount] = call I2CSlave.slaveReceive();
//    printf("r %d %x\n\r", transCount, rxPkt->buf[transCount]);
    transCount++;
  }

  void transmit(){
    if(transCount == 0){
      atomic{
        txPkt = signal I2CComSlave.slaveTXStart[lastClient](txPkt);
      }
    } 
    eventPending = FALSE;
    call I2CSlave.slaveTransmit(txPkt->body.buf[transCount]);
    transCount++;
  }
  
  async event bool I2CSlave.slaveReceiveRequested(){
    if (isGC){
      //ignore
      call I2CSlave.slaveReceive();
      return TRUE;
    } else{
      isReceive = TRUE;
      if (isPaused){
        eventPending = TRUE;
        return FALSE;
      } else {
        receive();
        return TRUE;
      }
    }
  }

  async event bool I2CSlave.slaveTransmitRequested(){
    if (isGC){
      //ignore
      call I2CSlave.slaveTransmit(0xff);
      return TRUE;
    }else {
      isReceive = FALSE;
      if (isPaused){
        eventPending = TRUE;
        return FALSE;
      } else {
        transmit();
        return TRUE;
      }
    }
  }
  
  async event void I2CSlave.slaveStart(bool generalCall){
    isGC = generalCall;
    transCount = 0;
  }
  

  //TODO: what should happen if we are paused when the stop arrives?
  //  can that happen?
  async event void I2CSlave.slaveStop(){
//    printf("%s: \n\r", __FUNCTION__);
    if (! isGC && isReceive){
      lastClient = rxPkt->body.header.clientId;
      atomic{
        rxPkt = signal I2CComSlave.received[lastClient](rxPkt);
      }
    }
  }

  default async event i2c_message_t* I2CComSlave.received[uint8_t clientId]( i2c_message_t* msg){
    printf("%s: \n\r", __FUNCTION__);
    return msg;
  }
  
  default async event i2c_message_t* I2CComSlave.slaveTXStart[uint8_t clientId](i2c_message_t* msg){
    printf("%s: \n\r", __FUNCTION__);
    return msg;
  }

}
 
