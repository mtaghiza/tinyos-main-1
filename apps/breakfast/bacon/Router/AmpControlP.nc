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

module AmpControlP{
  provides interface Rf1aPhysical;
  uses interface Rf1aPhysical as SubRf1aPhysical;
  uses interface GeneralIO as HGMPin;
  uses interface GeneralIO as LNA_ENPin;
  uses interface GeneralIO as PA_ENPin;
  uses interface GeneralIO as PowerPin;
  provides interface Init;
} implementation {

  command error_t Init.init(){
    call HGMPin.makeOutput();
    //TODO: always stay in HGM?
    call HGMPin.set();
    call LNA_ENPin.makeOutput();
    call LNA_ENPin.clr();
    call PA_ENPin.makeOutput();
    call PA_ENPin.clr();

    call PowerPin.makeOutput();
    call PowerPin.clr();
    return SUCCESS;
  }


  void txMode(){
    call PowerPin.set();
    call PA_ENPin.set();
    call LNA_ENPin.clr();
  }
  void rxMode(){
    call PowerPin.set();
    call LNA_ENPin.set();
    call PA_ENPin.clr();
  }

  command error_t Rf1aPhysical.send (uint8_t* buffer, unsigned int length,
      rf1a_offmode_t offMode){
    txMode();
    return call SubRf1aPhysical.send(buffer, length, offMode);
  }

  async command error_t Rf1aPhysical.startTransmission (bool check_cca, 
      bool targetFSTXON){
    txMode();
    return call SubRf1aPhysical.startTransmission(check_cca,
      targetFSTXON);
  }
  async command error_t Rf1aPhysical.startReception (){
    rxMode();
    return call SubRf1aPhysical.startReception();
  }
  async command error_t Rf1aPhysical.resumeIdleMode (bool rx ){
    if (rx){
      rxMode();
    }else{
      call PowerPin.clr();
    }
    return call SubRf1aPhysical.resumeIdleMode(rx);
  }
  async command error_t Rf1aPhysical.sleep (){
    call PowerPin.clr();
    return call SubRf1aPhysical.sleep();
  }
  async command error_t Rf1aPhysical.setReceiveBuffer (uint8_t* buffer,
                                          unsigned int length,
                                          bool single_use,
                                          rf1a_offmode_t offMode){
    return call SubRf1aPhysical.setReceiveBuffer(buffer, length,
      single_use, offMode);
  }

  async command int Rf1aPhysical.getChannel (){
    return call SubRf1aPhysical.getChannel();
  }
  async command int Rf1aPhysical.setChannel (uint8_t channel){
    return call SubRf1aPhysical.setChannel(channel);
  }
  async command int Rf1aPhysical.setPower (uint8_t powerSetting){
    return call SubRf1aPhysical.setPower(powerSetting);
  }
  async command int Rf1aPhysical.rssi_dBm (){
    return call SubRf1aPhysical.rssi_dBm();
  }
  async command void Rf1aPhysical.readConfiguration (rf1a_config_t* config){
    return call SubRf1aPhysical.readConfiguration(config);
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

  //events below
  async event void SubRf1aPhysical.sendDone (int result){
    call PowerPin.clr();
    signal Rf1aPhysical.sendDone(result);
  }
  async event void SubRf1aPhysical.receiveStarted (unsigned int length){
    signal Rf1aPhysical.receiveStarted(length);
  }
  async event void SubRf1aPhysical.receiveDone (uint8_t* buffer,
                                unsigned int count,
                                int result){
    call PowerPin.clr();
    signal Rf1aPhysical.receiveDone(buffer, count, result);
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
  async event void SubRf1aPhysical.carrierSense (){
    signal Rf1aPhysical.carrierSense();
  }
  async event void SubRf1aPhysical.released (){
    signal Rf1aPhysical.released();
  }
  
}
