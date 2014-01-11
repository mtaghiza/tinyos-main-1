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

generic module HplMsp430Rf1aLoggingP () @safe() {
  provides interface Rf1aPhysical[uint8_t client];
  uses interface Rf1aPhysical as SubRf1aPhysical[uint8_t client];

  provides interface ResourceConfigure[uint8_t client];
  uses interface ResourceConfigure as SubResourceConfigure[uint8_t client];
  
  provides interface Rf1aInterrupts[uint8_t client];
  uses interface Rf1aInterrupts as SubRf1aInterrupts[uint8_t client];

  uses interface Rf1aStatus;

  uses interface StateTiming;

  uses interface Alarm<T32khz, uint16_t>;
  provides interface Init;
} implementation {
  void captureState(){
    call StateTiming.start(call Rf1aStatus.get());
  }

  //check every half second, just in case something went wrong and
  //  we missed a transition.
  #ifndef RADIO_LOG_INTERVAL 
  #define RADIO_LOG_INTERVAL (32*512)
  #endif
  command error_t Init.init(){
    call Alarm.start(RADIO_LOG_INTERVAL);
    return SUCCESS;
  }

  async event void Alarm.fired(){
    captureState();
    call Alarm.start(RADIO_LOG_INTERVAL);
  }

  async command void ResourceConfigure.configure[uint8_t client] ()
  {
    captureState();
    call SubResourceConfigure.configure[client]();
    captureState();
  }

  async command void ResourceConfigure.unconfigure[uint8_t client] ()
  {
    captureState();
    call SubResourceConfigure.unconfigure[client]();
    captureState();
  }


  async command error_t Rf1aPhysical.startTransmission[uint8_t client] (bool with_cca)
  {
    error_t r;
    captureState();
    r = call SubRf1aPhysical.startTransmission[client](with_cca);
    captureState();
    return r;
  }

  async command error_t Rf1aPhysical.resumeIdleMode[uint8_t client] ()
  {
    error_t r;
    captureState();
    r = call SubRf1aPhysical.resumeIdleMode[client]();
    captureState();
    return r;
  }

  async command error_t Rf1aPhysical.startReception[uint8_t client] ()
  {
    error_t r;
    captureState();
    r = call SubRf1aPhysical.startReception[client]();
    captureState();
    return r;
  }

  async command error_t Rf1aPhysical.sleep[uint8_t client] ()
  {
    error_t r;
    captureState();
    r = call SubRf1aPhysical.sleep[client]();
    captureState();
    return r;
  }
     
  
  async command error_t Rf1aPhysical.setReceiveBuffer[uint8_t client] (uint8_t* buffer,
                                                                       unsigned int length,
                                                                       bool single_use)
  {
    error_t r;
    captureState();
    r = call SubRf1aPhysical.setReceiveBuffer[client](buffer, length,
      single_use);
    captureState();
    return r;
  }


  async command const uint8_t* Rf1aPhysical.defaultTransmitData[uint8_t client] (unsigned int count)
  {
    const uint8_t* r;
    captureState();
    r = call SubRf1aPhysical.defaultTransmitData[client](count);
    captureState();
    return r;
  }

  async event void SubRf1aInterrupts.rxFifoAvailable[uint8_t client] ()
  { 
    captureState();
    signal Rf1aInterrupts.rxFifoAvailable[client]();
    captureState();
  }

  async event void SubRf1aInterrupts.txFifoAvailable[uint8_t client] ()
  {
    captureState();
    signal Rf1aInterrupts.txFifoAvailable[client]();
    captureState();
  }

  async event void SubRf1aInterrupts.rxOverflow[uint8_t client] ()
  {
    captureState();
    signal Rf1aInterrupts.rxOverflow[client] ();
    captureState();
  }

  async event void SubRf1aInterrupts.txUnderflow[uint8_t client] ()
  {
    captureState();
    signal Rf1aInterrupts.txUnderflow[client] ();
    captureState();
  }

  async event void SubRf1aInterrupts.syncWordEvent[uint8_t client] ()
  {
    captureState();
    signal Rf1aInterrupts.syncWordEvent[client] ();
    captureState();
  }

  async event void SubRf1aInterrupts.clearChannel[uint8_t client] ()
  {
    signal Rf1aInterrupts.clearChannel[client]();
  }

  async event void SubRf1aInterrupts.carrierSense[uint8_t client] ()
  {
    signal Rf1aInterrupts.carrierSense[client]();
  }

  async event void SubRf1aInterrupts.coreInterrupt[uint8_t client] (uint16_t iv)
  {
    signal Rf1aInterrupts.coreInterrupt[client](iv);
  }
      
  default async event void Rf1aPhysical.receiveStarted[uint8_t client] (unsigned int length) { }

  default async event void Rf1aPhysical.receiveDone[uint8_t client] (uint8_t* buffer,
                                                                     unsigned int count,
                                                                     int result) { }

  default async event void Rf1aPhysical.receiveBufferFilled[uint8_t client] (uint8_t* buffer,
                                                                             unsigned int count) { }

  default async event void Rf1aPhysical.frameStarted[uint8_t client] () { }
  default async event void Rf1aPhysical.clearChannel[uint8_t client] () { }
  default async event void Rf1aPhysical.carrierSense[uint8_t client] () { }
  
  default async event void Rf1aPhysical.released[uint8_t client] () { }
  

  async command int Rf1aPhysical.getChannel[uint8_t client] ()
  {
    //no state change
    return call SubRf1aPhysical.getChannel[client] ();
  }

  async command int Rf1aPhysical.setChannel[uint8_t client] (uint8_t channel)
  {
    int r;
    captureState();
    r = call SubRf1aPhysical.setChannel[client] (channel);
    captureState();
    return r;
  }

  async command int Rf1aPhysical.rssi_dBm[uint8_t client] ()
  {
    int r;
    captureState();
    r = call SubRf1aPhysical.rssi_dBm[client] ();
    captureState();
    return r;
  }

  async command error_t Rf1aPhysical.completeSend[uint8_t clientId](){
    error_t r;
    captureState();
    r = call SubRf1aPhysical.completeSend[clientId]();
    captureState();
    return r;
  }

  async command unsigned int Rf1aPhysical.defaultTransmitReadyCount[uint8_t client] (unsigned int
  count){
    unsigned int r;
    captureState();
    r= call SubRf1aPhysical.defaultTransmitReadyCount[client](count);
    captureState();
    return r;
  }

  async command void Rf1aPhysical.readConfiguration[uint8_t client]
  (rf1a_config_t* config){
    call SubRf1aPhysical.readConfiguration[client](config);
  }

  async command void Rf1aPhysical.reconfigure[uint8_t client](){
    captureState();
    call SubRf1aPhysical.reconfigure[client]();
    captureState();
  }

  async command error_t Rf1aPhysical.startSend[uint8_t client](bool cca_check, 
      rf1a_offmode_t txOffMode){
    error_t r; 
    captureState();
    r = call SubRf1aPhysical.startSend[client](cca_check, txOffMode);
    captureState();
    return r;
  }

  async event bool SubRf1aPhysical.getPacket[uint8_t client](uint8_t** buffer, uint8_t* length){
    return signal Rf1aPhysical.getPacket[client](buffer, length);
  }

  async event void SubRf1aPhysical.sendDone [uint8_t client](uint8_t* buffer, uint8_t len, int result){
    captureState();
    signal Rf1aPhysical.sendDone[client](buffer, len, result);
  }

  async event bool SubRf1aPhysical.idleModeRx[uint8_t client](){
    return signal Rf1aPhysical.idleModeRx[client]();
  }

  async event void SubRf1aPhysical.receiveStarted [uint8_t client](unsigned int length){
    captureState();
    signal Rf1aPhysical.receiveStarted[client](length);
  }

  async event void SubRf1aPhysical.receiveDone [uint8_t client](uint8_t* buffer,
                                unsigned int count,
                                int result){
    captureState();
    signal Rf1aPhysical.receiveDone[client](buffer, count, result);
  }

  async event void SubRf1aPhysical.receiveBufferFilled [uint8_t client](uint8_t* buffer,
                                        unsigned int count){
    captureState();
    signal Rf1aPhysical.receiveBufferFilled[client](buffer, count);
  }

  async event void SubRf1aPhysical.frameStarted [uint8_t client](){
    signal Rf1aPhysical.frameStarted[client]();
  }

  async event void SubRf1aPhysical.clearChannel [uint8_t client](){
    signal Rf1aPhysical.clearChannel[client]();
  }

  async event void SubRf1aPhysical.carrierSense [uint8_t client](){
    signal Rf1aPhysical.carrierSense[client]();
  }

  async event void SubRf1aPhysical.released [uint8_t client](){
    signal Rf1aPhysical.released[client]();
  }

  async event uint8_t SubRf1aPhysical.getChannelToUse[uint8_t client](){
    return signal Rf1aPhysical.getChannelToUse[client]();
  }

  default async event uint8_t Rf1aPhysical.getChannelToUse[uint8_t client](){
    return 0;
  }

  default async event void Rf1aPhysical.sendDone[uint8_t client]
  (uint8_t* buffer, uint8_t len, int result) { }

  default async event bool Rf1aPhysical.getPacket[uint8_t clientId](uint8_t** buffer, uint8_t* length){
    return FALSE ;
  }

  default async event bool Rf1aPhysical.idleModeRx[uint8_t client](){
    return TRUE;
  }
}

/* 
 * Local Variables:
 * mode: c
 * End:
 */
