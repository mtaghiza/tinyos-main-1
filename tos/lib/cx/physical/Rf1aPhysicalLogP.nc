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

module Rf1aPhysicalLogP {
  uses interface Rf1aPhysical as SubRf1aPhysical;
  provides interface DelayedSend;
  uses interface DelayedSend as SubDelayedSend;
  provides interface Rf1aPhysical;
  provides interface RadioStateLog;
  uses interface LocalTime<T32khz>;
} implementation {

  uint32_t logBatch;

  enum{
    R_OFF = 0,
    R_SLEEP = 1,
    R_IDLE = 2, 
    R_FSTXON = 3,
    R_TX = 4,
    R_RX = 5,
    R_NUMSTATES = 6
  };

  const char labels[R_NUMSTATES] = {'o', 's', 'i', 'f', 't', 'r'};
  uint8_t  curRadioState = R_OFF;
  uint32_t lastRadioStateChange;
  uint32_t radioStateTimes[R_NUMSTATES];
  
  void radioStateChange(uint8_t newState, uint32_t changeTime){
    atomic{
      if (newState != curRadioState){
        uint32_t elapsed = changeTime-lastRadioStateChange;
        radioStateTimes[curRadioState] += elapsed;
        curRadioState = newState;
        lastRadioStateChange = changeTime;
      }
    }
  }

  uint32_t rst[R_NUMSTATES];
  
  bool logging = FALSE;
  uint8_t dc_i;

  task void logNextStat(){
    if (dc_i < R_NUMSTATES){
      cinfo(RADIOSTATS, "RS %lu %c %lu\r\n", 
        logBatch, labels[dc_i], rst[dc_i]);
      dc_i ++;
      post logNextStat();
    }else{
      logging = FALSE;
    }
  }

  command uint32_t RadioStateLog.dump(){
    if (!logging){
      atomic{
        uint8_t k;
        for (k = 0; k < R_NUMSTATES; k++){
          rst[k] = radioStateTimes[k];
        }
      }
      dc_i = 0;
      logging = TRUE;
      post logNextStat();
      return ++logBatch;
    }else {
      return 0;
    }
  }
  
  command error_t Rf1aPhysical.send (uint8_t* buffer, 
      unsigned int length, rf1a_offmode_t offMode){
    //no state change: controlled by startTransmission.
    return call SubRf1aPhysical.send(buffer, length, offMode);
  }

  async event void SubRf1aPhysical.sendDone (int result){
    radioStateChange(R_IDLE, call LocalTime.get());
    signal Rf1aPhysical.sendDone(result);
  }

  async command error_t Rf1aPhysical.startTransmission (bool check_cca, bool targetFSTXON){
    uint32_t ct = call LocalTime.get();
    error_t ret = call SubRf1aPhysical.startTransmission(check_cca, targetFSTXON);
    if (ret == SUCCESS){
      if (targetFSTXON){
        radioStateChange(R_FSTXON, ct);
      }else{
        radioStateChange(R_TX, ct);
      }
    }
    return ret;
  }

  async command error_t Rf1aPhysical.startReception (){
    //unused
    return call SubRf1aPhysical.startReception();
  }

  async command error_t Rf1aPhysical.resumeIdleMode (bool rx ){
    uint32_t ct = call LocalTime.get();
    error_t ret = call SubRf1aPhysical.resumeIdleMode(rx);
    if (ret == SUCCESS){
      if (rx){
        radioStateChange(R_RX, ct);
      }else{
        radioStateChange(R_IDLE, ct);
      }
    }
    return ret;
  }

  async command error_t Rf1aPhysical.sleep (){
    uint32_t ct = call LocalTime.get();
    error_t ret = call SubRf1aPhysical.sleep();
    if (ret == SUCCESS){
      radioStateChange(R_SLEEP, ct);
    }
    return ret;
  }

  async event void SubRf1aPhysical.receiveStarted (unsigned int length){
    signal Rf1aPhysical.receiveStarted(length);
  }
  async event void SubRf1aPhysical.receiveDone (uint8_t* buffer,
                                unsigned int count,
                                int result){
    radioStateChange(R_IDLE, call LocalTime.get());
    signal Rf1aPhysical.receiveDone(buffer, count, result);
  }
  async command error_t Rf1aPhysical.setReceiveBuffer (uint8_t* buffer,
                                          unsigned int length,
                                          bool single_use){
    uint32_t ct = call LocalTime.get();
    error_t ret = call SubRf1aPhysical.setReceiveBuffer(buffer, length,
      single_use);
    if (ret == SUCCESS && buffer != NULL){
      radioStateChange(R_RX, ct);
    }else {
      radioStateChange(R_IDLE, ct);
    }
    return ret;
  }

  async event void SubRf1aPhysical.receiveBufferFilled (uint8_t* buffer,
                                        unsigned int count){
    signal Rf1aPhysical.receiveBufferFilled(buffer, count);
  }
  async event void SubRf1aPhysical.frameStarted (){
    signal Rf1aPhysical.frameStarted();
  }
  async event void SubRf1aPhysical.clearChannel (){
    signal Rf1aPhysical.clearChannel();
  }
  
  event void SubDelayedSend.sendReady(){
    signal DelayedSend.sendReady();
  }

  async command error_t DelayedSend.startSend(){
    error_t ret = call SubDelayedSend.startSend();
    if (ret == SUCCESS){
      //if we fetch this before the call, we break synchronization
      //(this .get is to an async clock source and may take a while to
      //resolve)
      radioStateChange(R_TX, call LocalTime.get());
    }
    return ret;
  }

  async command void Rf1aPhysical.readConfiguration (rf1a_config_t* config){
    call SubRf1aPhysical.readConfiguration(config);
  }

  async command void Rf1aPhysical.reconfigure(){
    return call SubRf1aPhysical.reconfigure();
  }

  async command int Rf1aPhysical.enableCca(){
    return call SubRf1aPhysical.enableCca();
  }

  async command int Rf1aPhysical.disableCca(){
    return call SubRf1aPhysical.disableCca();
  }

  async command int Rf1aPhysical.rssi_dBm (){
    return call SubRf1aPhysical.rssi_dBm();
  }

  async command int Rf1aPhysical.setChannel (uint8_t channel){
    return call SubRf1aPhysical.setChannel(channel);
  }
  async command int Rf1aPhysical.getChannel (){
    return call SubRf1aPhysical.getChannel();
  }
  async event void SubRf1aPhysical.carrierSense () { 
    signal Rf1aPhysical.carrierSense();
  }
  async event void SubRf1aPhysical.released () { 
    signal Rf1aPhysical.released();
  }
}
