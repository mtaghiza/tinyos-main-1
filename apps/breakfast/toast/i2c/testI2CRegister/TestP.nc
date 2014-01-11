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

#include "decodeError.h"
#include "I2CDiscoverable.h"
module TestP{
  uses interface Boot;
  uses interface UartStream;
  uses interface UartByte;
  uses interface StdControl as UartControl;

  //for slave
  uses interface SplitControl;
  uses interface I2CDiscoverable;
  
  //for master
  uses interface I2CPacket<TI2CBasicAddr>;
  uses interface Resource;
  uses interface I2CDiscoverer;
} implementation {
  uint8_t count = 0;
  uint8_t rxByte;
  norace uint8_t globalAddr[GLOBAL_ADDR_LENGTH];
  uint16_t slaveAddr;
  uint8_t index;
  bool seeking = FALSE;
  
  typedef struct {
    uint8_t pos;
    union {
      uint8_t data[10];
      struct{
        uint8_t clientId;
        uint8_t data[9];
      } body;
    };
  } __attribute__((__packed__)) i2c_pkt_t;

  uint8_t readBackBuf[9];
  i2c_pkt_t pkt;

  void printGlobalAddr(){
    uint8_t i;
    printf("Global addr:");
    for(i = 0; i< GLOBAL_ADDR_LENGTH; i++){
      printf("%x ", globalAddr[i]);
    }
    printf("\n\r");
  }

  event void Boot.booted(){
    call UartControl.start();
    globalAddr[GLOBAL_ADDR_LENGTH - 1] = TOS_NODE_ID;
    printf("I2C Register Test\n\r");
  }

  event uint16_t I2CDiscoverer.getLocalAddr(){
    return TOS_NODE_ID;
  }

  event discoverer_register_union_t* I2CDiscoverer.discovered(discoverer_register_union_t* discovery){
    uint8_t i;
    slaveAddr = discovery -> val.localAddr;
    printf("Assigned %x to ", slaveAddr);
    for (i = 0; i < I2C_GLOBAL_ADDR_LENGTH; i++){
      printf("%x", discovery -> val.globalAddr[i]);
    }
    printf("\n\r");
    return discovery;
  }

  event void I2CDiscoverer.discoveryDone(error_t error){
    printf("%s: %s\n\r", __FUNCTION__, decodeError(error));
  }

  event uint8_t* I2CDiscoverable.getGlobalAddr(){
    return globalAddr;
  }

  event void I2CDiscoverable.assigned(error_t err, uint16_t lastLocalAddr){
    printf("Assigned to %x\n\r", lastLocalAddr);
  }



  event void SplitControl.startDone(error_t error){
    printf("Register/discoverable started\n\r");
  }

  event void SplitControl.stopDone(error_t error){
    printf("%s: %s\n\r", __FUNCTION__, decodeError(error));
    call Resource.request();
  }

  task void slaveStart(){
    error_t error = call SplitControl.start();
    printf("%s: %s\n\r", __FUNCTION__, decodeError(error));
  }

  task void masterStart(){
    printf("stop slave: %s\n\r", decodeError(call SplitControl.stop()));
    printf("Start discoverer: %s\n\r", decodeError(call I2CDiscoverer.startDiscovery(TRUE, 0x40)));
  }

  task void write(){
    pkt.pos = 0;
    pkt.body.clientId = 0x01;
    printf("%s: \n\r", __FUNCTION__ );
    printf("call write with %x %d %p\n\r", slaveAddr, sizeof(pkt), &pkt);
    printf("Write: %s \n\r", decodeError(call
    I2CPacket.write(I2C_START|I2C_STOP, slaveAddr, sizeof(pkt), (uint8_t*)&pkt)));
  }

  task void startWrite(){
    printf("%s: \n\r", __FUNCTION__);
    if (! call Resource.isOwner()){
      call Resource.request();
    } else {
      post write();
    }
  }

  event void Resource.granted(){
    printf("%s: \n\r", __FUNCTION__);
    post write();
  }

  task void seek(){
    //position 0 = client ID, so read from 1
    pkt.pos = 1;
    seeking = TRUE;
    printf("%s: %s\n\r", __FUNCTION__, decodeError(call I2CPacket.write(I2C_START, slaveAddr, 1, (uint8_t*)&pkt)));
  }

  task void read(){
    error_t error;
    memset(readBackBuf, 9, 0x00);
    error = call I2CPacket.read(I2C_RESTART|I2C_STOP, slaveAddr, 9, readBackBuf);
    printf("%s: %s\n\r", __FUNCTION__, decodeError(error));
  }

  async event void I2CPacket.readDone(error_t error, uint16_t addr, uint8_t len, uint8_t* data){
    uint8_t i; 
    printf("%s: %s\n\r", __FUNCTION__, decodeError(error));
    printf("Read back: ");
    for (i = 0; i < len; i++){
      printf("%c", data[i]);
    }
    printf("\n\r");
  }

  async event void I2CPacket.writeDone(error_t error, uint16_t addr, uint8_t len, uint8_t* data){
    printf("%s: %s %x %d %p\n\r", __FUNCTION__, decodeError(error), addr, len, data);
    if (seeking){
      seeking = FALSE;
      post read();
    }
  }

  async event void UartStream.receivedByte(uint8_t byte){
    atomic rxByte = byte;
    switch(rxByte){
      case 'q':
        WDTCTL = 0x00;
        break;
      case 's':
        post slaveStart();
        break;
      case 'd':
        post masterStart();
        break;
      case 'w':
        post startWrite();
        break;
      case 'r':
        post seek();
        break;
      case '\r':
        printf("\n\r");
        count = 0;
        break;
      case '?':
        break;
      default:
        printf("%c", byte);
        pkt.body.data[count % 9] = byte;
        count++;
        break;
    }
  }

  async event void UartStream.receiveDone(uint8_t* buf, uint16_t len, error_t err){};
  async event void UartStream.sendDone(uint8_t* buf, uint16_t len, error_t err){};
}
