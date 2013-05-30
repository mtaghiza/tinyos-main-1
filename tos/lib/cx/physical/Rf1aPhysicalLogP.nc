module Rf1aPhysicalLogP {
  uses interface Rf1aPhysical as SubRf1aPhysical;
  provides interface DelayedSend;
  uses interface DelayedSend as SubDelayedSend;
  provides interface Rf1aPhysical;
  provides interface RadioStateLog;
  uses interface LocalTime<T32khz>;
} implementation {

  command error_t RadioStateLog.dump(){
    return EBUSY;
  }
  
  command error_t Rf1aPhysical.send (uint8_t* buffer, 
      unsigned int length, rf1a_offmode_t offMode){
    return call SubRf1aPhysical.send(buffer, length, offMode);
  }

  async event void SubRf1aPhysical.sendDone (int result){
    signal Rf1aPhysical.sendDone(result);
  }

  async command error_t Rf1aPhysical.startTransmission (bool check_cca, bool targetFSTXON){
    return call SubRf1aPhysical.startTransmission(check_cca, targetFSTXON);

  }
  async command error_t Rf1aPhysical.startReception (){
    return call SubRf1aPhysical.startReception();
  }
  async command error_t Rf1aPhysical.resumeIdleMode (bool rx ){
    return call SubRf1aPhysical.resumeIdleMode(rx);
  }

  async command error_t Rf1aPhysical.sleep (){
    return call SubRf1aPhysical.sleep();
  }

  async event void SubRf1aPhysical.receiveStarted (unsigned int length){
    signal Rf1aPhysical.receiveStarted(length);
  }
  async event void SubRf1aPhysical.receiveDone (uint8_t* buffer,
                                unsigned int count,
                                int result){
    signal Rf1aPhysical.receiveDone(buffer, count, result);
  }
  async command error_t Rf1aPhysical.setReceiveBuffer (uint8_t* buffer,
                                          unsigned int length,
                                          bool single_use){
    return call SubRf1aPhysical.setReceiveBuffer(buffer, length,
      single_use);
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
    return call SubDelayedSend.startSend();
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
