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

module I2CDiscovererRegisterP{
  uses interface I2CRegister;
  uses interface I2CPacket<TI2CBasicAddr>;
  uses interface SplitControl as RegisterSplitControl;
  uses interface Resource as MasterResource;
  provides interface SplitControl as DiscovererSplitControl;
  provides interface I2CDiscoverer;
} implementation {
  enum{
    S_INIT,
    S_IDLE,
    S_IDLE_START,
    S_HEAD_FOUND,
    S_HEAD_FOUND_START,
    S_CLAIM_SWITCH,
    S_CLAIM_READY,
    S_CLAIMING,
    S_READING_LOCAL,
    S_ASSIGNED,
    S_ERROR,
    S_STARTING_REGISTER,
  };
  uint8_t state = S_INIT;
  uint16_t localAddr = I2C_DISCOVERABLE_UNASSIGNED;
  uint16_t masterAddr = I2C_INVALID_MASTER;

  void setState(uint8_t s){
    atomic state = s;
  }

  command error_t DiscoverableSplitControl.start(){
    error_t ret;
    if(checkState(S_INIT)){
      ret = call RegisterSplitControl.start() 
      if (ret == SUCCESS){
        setState(S_STARTING_REGISTER);
      }else {
        setState(S_ERROR);
      }
      return ret;
    }else {
      return FAIL;
    }
  }

  event void RegisterSplitControl.startDone(error_t err){
    printf("%s: \n\r", __FUNCTION__);
    if (err == SUCCESS){
    }
  }

  async event void I2CRegister.transactionStart(bool generalCall){
    printf("%s: \n\r", __FUNCTION__);
    switch(state){
      case S_IDLE:
        setState(S_IDLE_START);
        break;
      case S_HEAD_FOUND:
        setState(S_HEAD_FOUND_START);
        break;
      default:
        setState(S_ERROR);
        break;
    }
  }

  async event uint8_t* I2CRegister.transactionStop(uint8_t* reg, uint8_t len, uint8_t gcCmd){
    printf("%s: \n\r", __FUNCTION__);
    switch(state){
      case S_IDLE_START:
        if(gcCmd & 0x01){
          masterAddr = gcCmd >> 1;
          setState(S_HEAD_FOUND);
        } else {
          printf("Expected 1 in LSB, got 0\n\r");
          setState(S_ERROR);
        }
        break;
      default:
        setState(S_ERROR);
        break;
    }
  }

  
  command uint16_t I2CDiscoverable.getLocalAddr(){
    printf("%s: \n\r", __FUNCTION__);
    return localAddr;
  }
}
