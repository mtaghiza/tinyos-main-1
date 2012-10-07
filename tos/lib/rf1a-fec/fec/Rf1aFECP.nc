generic module Rf1aFECP () {
  provides interface Rf1aPhysical[uint8_t client];
  uses interface Rf1aPhysical as SubRf1aPhysical[uint8_t client];
} implementation {
  
  command error_t Rf1aPhysical.send[uint8_t client] (uint8_t* buffer,
      unsigned int length){
    return call SubRf1aPhysical.send[client](buffer, length);
  }
  async command error_t Rf1aPhysical.startTransmission[uint8_t client](
      bool check_cca){
    return call SubRf1aPhysical.startTransmission[client](check_cca);
  }
  async command error_t Rf1aPhysical.startReception[uint8_t client]
  (){
    return call SubRf1aPhysical.startReception[client]();
  }
  async command error_t Rf1aPhysical.resumeIdleMode[uint8_t client]
  (){
    return call SubRf1aPhysical.resumeIdleMode[client]();
  }
  async command error_t Rf1aPhysical.sleep[uint8_t client] (){
    return call SubRf1aPhysical.sleep[client]();
  }
  async command error_t Rf1aPhysical.setReceiveBuffer[uint8_t client] (uint8_t* buffer,
                                          unsigned int length,
                                          bool single_use){
    return call SubRf1aPhysical.setReceiveBuffer[client](buffer,
      length, single_use);
  }
  async command unsigned int
  Rf1aPhysical.defaultTransmitReadyCount[uint8_t client] (unsigned int
  count){
    return call
    SubRf1aPhysical.defaultTransmitReadyCount[client](count);
  }
  async command const uint8_t*
  Rf1aPhysical.defaultTransmitData[uint8_t client] (unsigned int
  count){
    return call SubRf1aPhysical.defaultTransmitData[client](count);
  }
  async command int Rf1aPhysical.getChannel[uint8_t client] (){
    return call SubRf1aPhysical.getChannel[client]();
  }
  async command int Rf1aPhysical.setChannel[uint8_t client] (uint8_t channel){
    return call SubRf1aPhysical.setChannel[client](channel);
  }
  async command int Rf1aPhysical.rssi_dBm[uint8_t client] (){
    return call SubRf1aPhysical.rssi_dBm[client]();
  }
  async command void Rf1aPhysical.readConfiguration[uint8_t client] (rf1a_config_t* config){
    return call SubRf1aPhysical.readConfiguration[client](config);
  }
  async command int Rf1aPhysical.enableCca[uint8_t client](){
    return call SubRf1aPhysical.enableCca[client]();
  }
  async command int Rf1aPhysical.disableCca[uint8_t client](){
    return call SubRf1aPhysical.disableCca[client]();
  }



  default async event void Rf1aPhysical.receiveStarted[uint8_t client]
  (unsigned int length){}
  async event void SubRf1aPhysical.receiveStarted[uint8_t client]
  (unsigned int length){
    signal Rf1aPhysical.receiveStarted[client](length);
  }

  default async event void Rf1aPhysical.receiveDone[uint8_t client] (uint8_t* buffer,
                                unsigned int count,
                                int result){}
  async event void SubRf1aPhysical.receiveDone[uint8_t client] (uint8_t* buffer,
                                unsigned int count,
                                int result){
    signal Rf1aPhysical.receiveDone[client](buffer, count, result);
  }

  default async event void Rf1aPhysical.receiveBufferFilled[uint8_t client] (uint8_t* buffer,
                                        unsigned int count){}
  async event void SubRf1aPhysical.receiveBufferFilled[uint8_t client] (uint8_t* buffer,
                                        unsigned int count){
    signal Rf1aPhysical.receiveBufferFilled[client](buffer, count);
  }

  default async event void Rf1aPhysical.frameStarted[uint8_t client] (){}
  async event void SubRf1aPhysical.frameStarted[uint8_t client] (){
    signal Rf1aPhysical.frameStarted[client]();
  }
  
  default async event void Rf1aPhysical.clearChannel[uint8_t client] (){}
  async event void SubRf1aPhysical.clearChannel[uint8_t client] (){
    signal Rf1aPhysical.clearChannel[client]( );
  }

  default async event void Rf1aPhysical.carrierSense[uint8_t client] (){}
  async event void SubRf1aPhysical.carrierSense[uint8_t client] (){
    signal Rf1aPhysical.carrierSense[client]( );
  }

  default async event void Rf1aPhysical.released[uint8_t client] (){}
  async event void SubRf1aPhysical.released[uint8_t client] (){
    signal Rf1aPhysical.released[client]( );
  }
  default async event void Rf1aPhysical.sendDone[uint8_t client] (int result){}
  async event void SubRf1aPhysical.sendDone[uint8_t client] (int result){
    signal Rf1aPhysical.sendDone[client](result);
  }
}
