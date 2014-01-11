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

generic module I2CRegisterP(uint8_t registerLength){
  provides interface I2CRegister;
  provides interface SplitControl;
  uses interface Resource;
  uses interface I2CSlave;
  uses interface I2CPacket<TI2CBasicAddr>;
  //TODO: i2cconfigure?
} implementation {
  uint8_t pos;
  uint8_t _reg[registerLength];
  uint8_t* reg = _reg;
  uint8_t transCount;
  bool isGC;
  uint8_t gcCmd;

  async command error_t I2CRegister.pause(){
    printf("%s: \n\r", __FUNCTION__);
  }

  async command error_t I2CRegister.unPause(){
    printf("%s: \n\r", __FUNCTION__);
  }

  command void I2CRegister.setOwnAddress(uint16_t addr){
    call I2CSlave.setOwnAddress(addr);
  }
  
  command error_t SplitControl.start(){
    return call Resource.request();
  }

  task void stopDone(){
    signal SplitControl.stopDone(SUCCESS);
  }

  command error_t SplitControl.stop(){
    error_t ret = call Resource.release();
    printf("%s: \n\r", __FUNCTION__);
    if (ret == SUCCESS){
      post stopDone();
    }
    return ret;
  }

  event void Resource.granted(){
    signal SplitControl.startDone(SUCCESS);
  }

  async event void I2CPacket.readDone(error_t error, uint16_t addr, uint8_t length, uint8_t* data){
  }

  async event void I2CPacket.writeDone(error_t error, uint16_t addr, uint8_t length, uint8_t* data){
  }
  
  void receive(){
      uint8_t data = call I2CSlave.slaveReceive();
      printf("RX %x", data);
      if (isGC && transCount < 2) {
        //General call: 0th byte is reset/setaddr/announce. standard
        //behavior begins after this.
        if(transCount == 0){
          printf(" -> gcCmd\n\r");
          gcCmd = data;
        }else{
          printf(" -> pos\n\r");
          pos = data;
        }
      } else {
        if(transCount == 0){
          printf(" -> pos\n\r");
          pos = data;
        }else {
          printf(" -> reg[%x]\n\r", pos%registerLength);
          reg[pos%registerLength] = data;
          pos++;
        }
      }
      transCount++;
  }

  async event bool I2CSlave.slaveReceiveRequested(){
    receive();
    return TRUE;
  }

  void transmit(){
    transCount++;
    call I2CSlave.slaveTransmit(0xff);
  }

  async event bool I2CSlave.slaveTransmitRequested(){
    transmit();
    return TRUE;
  }
  
  async event void I2CSlave.slaveStart(bool generalCall){
    signal I2CRegister.transactionStart(generalCall);
    isGC = generalCall;
    transCount = 0;
  }

  async event void I2CSlave.slaveStop(){
    printf("%s: \n\r", __FUNCTION__);
    signal I2CRegister.transactionStop(reg, registerLength, gcCmd);
  }

}
