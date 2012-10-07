generic module Rf1aFECP () {
  provides interface Rf1aPhysical[uint8_t client];
  provides interface Rf1aPhysicalMetadata;
  uses interface Rf1aPhysical as SubRf1aPhysical[uint8_t client];
  uses interface Rf1aPhysicalMetadata as SubRf1aPhysicalMetadata;
  uses interface FEC;
  uses interface Crc;
} implementation {

  //TODO: resolve atomicity warnings

  //buffer swapping behavior:
  //  -  make sure that sendDone(buf) matches send(buf)
  //  -  make sure that receiveDone(buf) matches setRxBuf(buf)
  //  -  make sure that what we signal in sendDone is decoded
  // send : encode to local buffer, signal sendDone with cached copy
  // receive : decode to local buffer, copy back

  uint8_t txEncoded[64];
  uint8_t rxEncoded[64];
  uint8_t* rxBuf;
  bool sendOutstanding;
  bool lastCrcPassed;

  command error_t Rf1aPhysical.send[uint8_t client] (uint8_t* buffer,
      unsigned int length){
    if (! sendOutstanding){
      error_t err;
      uint8_t encodedLen;
      //compute CRC
      uint16_t crc = call Crc.crc16(buffer, length);
      //append CRC to buffer
      *((uint16_t*)(&buffer[length])) = crc;
      //encode to new buffer and get encoded length
      encodedLen = call FEC.encode(buffer, txEncoded, length + sizeof(crc));
      //pass it down
      err  = call SubRf1aPhysical.send[client](txEncoded, encodedLen);
      if (err == SUCCESS){
        sendOutstanding = TRUE;
      }
      return err;
    }else{
      return EBUSY;
    }
  }

  async event void SubRf1aPhysical.sendDone[uint8_t client] (int result){
    sendOutstanding = FALSE;
    signal Rf1aPhysical.sendDone[client](result);
  }

  async command error_t Rf1aPhysical.setReceiveBuffer[uint8_t client] (uint8_t* buffer,
                                          unsigned int length,
                                          bool single_use){
    rxBuf = buffer;
    return call SubRf1aPhysical.setReceiveBuffer[client](rxEncoded,
      length, single_use);
  }

  async event void SubRf1aPhysical.receiveDone[uint8_t client] (uint8_t* buffer,
                                unsigned int count,
                                int result){
    if (buffer == rxEncoded && rxBuf != NULL){
      uint8_t decodedLen = call FEC.decode(buffer, rxBuf, count);
      uint8_t decodedPayloadLen = decodedLen - sizeof(uint16_t);
      uint16_t computedCrc = call Crc.crc16(rxBuf,
        decodedPayloadLen);
      uint16_t decodedCrc = *((uint16_t*)(&rxBuf[decodedPayloadLen]));
      uint8_t* rxBufTmp = rxBuf;

      //override crcPassed metadata- store result in this
      //component and intercept storeMetadata call 
      if (decodedCrc != computedCrc){
        lastCrcPassed = FALSE;
      }else{
        lastCrcPassed = TRUE;
      }
      rxBuf = NULL;
      signal Rf1aPhysical.receiveDone[client](rxBufTmp, count, result);
    }else{
      //TODO: what the hell happened?
    }
  }

  async command void Rf1aPhysicalMetadata.store (rf1a_metadata_t* metadatap){
    call SubRf1aPhysicalMetadata.store(metadatap);
    if (lastCrcPassed){
      metadatap->lqi |= 0x80;
    }else{
      metadatap->lqi &= ~0x80;
    }
  }

  async command int Rf1aPhysicalMetadata.rssi (const rf1a_metadata_t* metadatap){
    return call SubRf1aPhysicalMetadata.rssi(metadatap);
  }

  async command int Rf1aPhysicalMetadata.lqi (const rf1a_metadata_t* metadatap){
    return call SubRf1aPhysicalMetadata.lqi(metadatap);
  }

  async command bool Rf1aPhysicalMetadata.crcPassed (const rf1a_metadata_t* metadatap){
    return call SubRf1aPhysicalMetadata.crcPassed(metadatap);
  }

  //-----------  Pass-throughs and defaults

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
}
