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

#include "I2C.h"
module TestP{
  uses interface Boot;
  uses interface UartStream;
  uses interface UartByte;
  uses interface StdControl;
  uses interface Timer<TMilli>;

  provides interface Msp430UsciConfigure as I2CConfigure;
  uses interface I2CPacket<TI2CBasicAddr>;
  uses interface I2CSlave;
  uses interface Resource as I2CResource;

  uses interface GpioInterrupt as OWInterrupt;
  uses interface GeneralIO as OWIO;
} implementation {

  //- reset
  //- toggle isSender:
  //  - set own address to senderAddress
  //  - enable interrupt
  //- modify my data-to-send
  //- trigger interrupt

  uint16_t receiverAddr = 0x0A;
  uint16_t senderAddr = 0x0B;

  uint8_t idleMsg[]    = ".";              //1
  uint8_t nl[] = "\n\r";                   //2
  uint8_t welcomeMsg[] = "I2C Multi-Master Test\n\r"; //23
  uint8_t isSenderMsg[] = "Is sender: x\n\r";//14/11
  uint8_t writeDoneMsg[] = "WRITE DONE\n\r"; //12
  uint8_t writeDoneFailMsg[] = "WRITE DONE FAIL\n\r"; //17
  uint8_t writeArbitrationLostMsg[] = "WRITE ARBITRATION LOST\n\r";//24

  uint8_t txBuf[] = "X";
  uint8_t rxBuf[] = "-";

  uint8_t rxByte;
  bool isSender;
  
  enum{
    S_INIT = 0x01,
    S_IDLE = 0x02,
  };

  uint8_t state = S_INIT;

  void setState(uint8_t s){
    atomic{
      state = s;
      P6OUT = state;
    }
  }

  bool checkState(uint8_t s){
    atomic return (state == s);
  }

  task void restartTimer(){
    call Timer.startOneShot(2048);
  }

  event void Boot.booted(){
    atomic{
      P6DIR = 0xff;
      P6SEL = 0x00;
      P6OUT = 0x00;
    }
    call OWIO.makeOutput();
    call OWIO.clr();
    call StdControl.start();
    call I2CResource.request();
  }


  event void I2CResource.granted(){
    call UartStream.send(welcomeMsg, 23);
  }

  event void Timer.fired(){
    if(checkState(S_IDLE)){
      call UartStream.send(idleMsg, 1);
    }
  }

  async event void UartStream.sendDone(uint8_t* buf, uint16_t len, error_t err){
    setState(S_IDLE);
    post restartTimer();
  }

  task void echoTask(){
    call UartStream.send(&rxByte, 1);
  }

  task void nlTask(){
    call UartStream.send(nl, 2);
  }


  async event void UartStream.receivedByte(uint8_t byte){
    atomic{
      rxByte = byte;
    }
    switch (rxByte){
      case 'q':
        WDTCTL = 0x00;
        break;
      case '\r':
        post nlTask();
        break;
      case 's':
        isSender = !isSender;
        if (isSender){
          call I2CSlave.setOwnAddress(senderAddr);
          call OWIO.makeInput();
          call OWInterrupt.enableRisingEdge();
        }else{
          call I2CSlave.setOwnAddress(receiverAddr);
          call OWInterrupt.disable();
          call OWIO.makeOutput();
          call OWIO.clr();
        }
        isSenderMsg[11] = isSender? 'Y':'N';
        call UartStream.send(isSenderMsg, 14);
        break;
      case 'c':
        txBuf[0]++;
        call UartStream.send(txBuf, 1);
        break;
      case 't':
        call OWIO.clr();
        call OWIO.set();
        call OWIO.clr();
        break;
      default:
        post echoTask();
    }
  }

  async event void I2CPacket.writeDone(error_t error, uint16_t addr, uint8_t length, uint8_t* data){
    if(error == SUCCESS){
      call UartStream.send(writeDoneMsg, 12);
    } else if(error == EBUSY){
      call UartStream.send(writeArbitrationLostMsg, 24);
    }else{
      call UartStream.send(writeDoneFailMsg, 17);
    }
  }

  async event void UartStream.receiveDone(uint8_t* buf, uint16_t len, error_t err){
  }

  const msp430_usci_config_t i2c_cfg = {
    ctl0: UCSYNC | UCMODE_3 | UCMM,
    ctl1: UCSSEL_2,
    br0:  0x08,
    br1:  0x00,
    mctl: 0,
    i2coa: 'A',
  };


  async command const msp430_usci_config_t* I2CConfigure.getConfiguration(){
    return &i2c_cfg;
  }

  async event void I2CPacket.readDone(error_t error, uint16_t addr, uint8_t length, uint8_t* data){
  }
  
  async event error_t I2CSlave.slaveReceive(uint8_t b){
    rxBuf[0] = b;
    return SUCCESS;
  }

  async event uint8_t I2CSlave.slaveTransmit(){
    return 0xff;
  }

  async event void I2CSlave.slaveStart(){
    rxBuf[0]='-';
  }

  async event void I2CSlave.slaveStop(){
    call UartStream.send(rxBuf, 1);
  }
  
  task void tryWriteAL(){
    call I2CPacket.write(I2C_START | I2C_STOP, receiverAddr, 1, txBuf);
  }

  async event void OWInterrupt.fired(){
    post tryWriteAL();
  }

}
