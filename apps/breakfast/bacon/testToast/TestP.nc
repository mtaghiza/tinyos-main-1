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

#include "I2CDiscoverable.h"
#include "decodeError.h"

#include "TestToast.h"
module TestP{
  uses interface Boot;
  uses interface UartStream as SubUartStream;
  uses interface StdControl;
  uses interface Leds;

  uses interface I2CDiscoverer;

  provides interface Get<test_state_t*>;
  uses interface Get<const char*> as GetDesc[uint8_t testClient];
  provides interface UartStream[uint8_t testClient];

  uses interface SplitControl as BusControl;

} implementation {
  norace test_state_t state;
  norace uint8_t currentTest;

  command test_state_t* Get.get(){
    return &state;
  }

  event void Boot.booted(){
    call StdControl.start();
    call BusControl.start();
    printf("Test Toast apps\n\r '~' to switch apps. Current app: %s\n\r", call GetDesc.get[currentTest]());
  }

  event void BusControl.startDone(error_t error){
  }

  event void BusControl.stopDone(error_t error){
  }

  task void startDiscovery(){
    printf("Start discovery\n\r");
    state.slaveCount = 0;
    state.currentSlave = 0;
    call I2CDiscoverer.startDiscovery(TRUE, 0x40);
  }

  event uint16_t I2CDiscoverer.getLocalAddr(){
    return TOS_NODE_ID & 0x7F;
  }

  event discoverer_register_union_t* I2CDiscoverer.discovered(discoverer_register_union_t* discovery){
    uint8_t i;
    state.slaves[state.slaveCount] = discovery->val.localAddr;
    printf("Assigned %x to ", discovery->val.localAddr);
    for ( i = 0 ; i < GLOBAL_ID_LEN; i++){
      printf("%x ", discovery->val.globalAddr[i]);
    }
    printf("\n\r");
    state.slaveCount++;
    return discovery;
  }

  event void I2CDiscoverer.discoveryDone(error_t error){
    printf("%s: %s\n\r", __FUNCTION__, decodeError(error));
  }

  async event void SubUartStream.receivedByte(uint8_t byte){
    switch ( byte ){
      case 'd':
        post startDiscovery();
        break;
      case 'n':
        printf("Next slave: ");
        state.currentSlave = (state.currentSlave+1)% state.slaveCount;
        printf("%x\n\r", state.slaves[state.currentSlave]);
        break;
      case '~':
        currentTest = (currentTest + 1) % uniqueCount(UQ_TEST_CLIENT);
        printf("Current Test: %s\n\r", call GetDesc.get[currentTest]());
        break;
      case 'q':
        WDTCTL = 0;
        break;
      case '\r':
        printf("\n\r");
        break;
      default:
        signal UartStream.receivedByte[currentTest](byte);
    }
  }
  
  async event void SubUartStream.receiveDone( uint8_t* buf_, uint16_t len,
    error_t error ){}
  async event void SubUartStream.sendDone( uint8_t* buf_, uint16_t len,
    error_t error ){}

  async command error_t UartStream.send[uint8_t clientId]( uint8_t* buf, uint16_t len ){ return FAIL; }
  async command error_t UartStream.receive[uint8_t clientId]( uint8_t* buf, uint16_t len ){ return FAIL; }
  async command error_t UartStream.enableReceiveInterrupt[uint8_t clientId](){return FAIL;}
  async command error_t UartStream.disableReceiveInterrupt[uint8_t clientId](){return FAIL;}
  
  const char* noDesc = "NONE\n\r";
  default command const char* GetDesc.get[uint8_t clientId](){
    return noDesc;
  }
  default async event void UartStream.receivedByte
    [uint8_t clientId](uint8_t byte){}
}
