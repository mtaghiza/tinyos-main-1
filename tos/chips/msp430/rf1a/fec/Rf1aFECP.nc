
generic module Rf1aFECP () {
  provides interface Rf1aPhysical[uint8_t client];
  provides interface Rf1aPhysicalMetadata;

  uses interface Rf1aPhysical as SubRf1aPhysical[uint8_t client];
  uses interface Rf1aPhysicalMetadata as SubRf1aPhysicalMetadata;

  uses interface Rf1aTransmitFragment[uint8_t client];
  provides interface Rf1aTransmitFragment as SubRf1aTransmitFragment[uint8_t client];
  
  uses interface Rf1aTransmitFragment as DefaultRf1aTransmitFragment;
  uses interface SetNow<uint8_t> as DefaultLength;
  uses interface SetNow<const uint8_t*> as DefaultBuffer;
  uses interface FEC;
  uses interface Crc;
} implementation {

  //buffer swapping behavior:
  //  -  make sure that sendDone(buf) matches send(buf)
  //  -  make sure that receiveDone(buf) matches setRxBuf(buf)
  //  -  make sure that what we signal in sendDone is decoded
  // send : encode to local buffer, signal sendDone with cached copy
  // receive : decode to local buffer, copy back
  

  //TODO: should be 2 x sizeof(header + TOSH_DATA_LENGTH)
  // OR
  //Ideally, this logic should be able to handle recycling the encoded buffer (e.g.
  //circular buffer of length 2n, generate/supply first n bytes,
  //acquire/encode next n, wait until first are cleared, then
  //continue.  This would be a huge increase in code space, I should
  //think (for a few hundred bytes RAM), so not worth it.
  uint8_t txEncoded[2*sizeof(message_t)];
  uint8_t rxEncoded[2*sizeof(message_t)];
  
  uint8_t* rxBuf;
  
  //write to sendOutstanding in SendDone is safe: will only get this
  //in response to send (with SUCCESS), and the call to Send + set of
  //sendOutstanding is done atomically
  norace bool sendOutstanding;

  bool lastCrcPassed;
  
  //pointer to beginning of encoded + ready data
  uint8_t* encodedPos;
  //indicate how many bytes (starting at encodedPos) are available for
  //transmission
  uint8_t encodedReady;
  
  //total length of raw data, number of raw bytes already encoded.
  uint8_t rawLen;
  uint8_t encodedSoFar;

  //the CRC of the currently-transmitting packet (updated as the raw
  //data is encoded)
  uint16_t runningCRC;
  bool crcAppended;

  uint8_t txClient;


  //encode as much as possible from the current transmitter, updating
  //encodedReady/rawReady etc as needed.
  task void encodeAMAP(){
    uint8_t rawReady 
      = call Rf1aTransmitFragment.transmitReadyCount[txClient](rawLen - encodedSoFar);
    uint8_t* epLocal;
    uint8_t numEncoded;

    //get pointer to start of ready data
    const uint8_t* rawPos = call Rf1aTransmitFragment.transmitData[txClient](rawReady); 
    //stash current encodedPos in case we get interrupted during this
    //process
    atomic{
      epLocal = encodedPos;
    }

    //encode whatever's now ready, update info about how much is
    //encoded.
    numEncoded = call FEC.encode(
      rawPos,
      epLocal,
      rawReady
    );
    encodedSoFar += rawReady;

    //update runningCRC with just-provided data
    runningCRC = call Crc.seededCrc16(runningCRC, rawPos,
      rawReady);

    //append encoded CRC if we're finished encoding but haven't already applied it.
    if (rawLen - encodedSoFar == 0 && !crcAppended){
      nx_uint16_t nxCRC;
      nxCRC = runningCRC;
      numEncoded += call FEC.encode((const uint8_t*)(&nxCRC), 
        epLocal + call FEC.encodedLen(rawLen),
        sizeof(nxCRC));

      crcAppended = TRUE;
    }
    //now that we're done with this chunk, update the amount of
    //encoded data available.
    atomic{
      encodedReady += numEncoded;
    }

  }

  command error_t Rf1aPhysical.send[uint8_t client] (uint8_t* buffer,
      unsigned int length){
    atomic{
      if (sendOutstanding){
        return EBUSY;
      }
    }
    {
      error_t err;
      uint8_t encodedLen;
      //setup for transmission: initialize vars, save client
      encodedPos = txEncoded;
      encodedSoFar = 0; 
      encodedReady = 0;
      runningCRC = 0;
      crcAppended = FALSE;
      rawLen = length;
      txClient = client;
      atomic{
        //hmm... I only want to wire this in if there's nothing
        //  connected to the real R1aFragment interface.
        call DefaultBuffer.setNow(buffer);
        call DefaultLength.setNow(length);
      }
      post encodeAMAP();
  
      encodedLen = call FEC.encodedLen(length + sizeof(runningCRC));
  
      //start up the phy layer's transmission
      atomic{
        err  = call SubRf1aPhysical.send[client](encodedPos, encodedLen);
        sendOutstanding =  (err == SUCCESS);
      }
      return err;
    }
  }

  async event void SubRf1aPhysical.sendDone[uint8_t client] (int result){
    sendOutstanding = FALSE;
    signal Rf1aPhysical.sendDone[client](result);
  }

  async command error_t Rf1aPhysical.setReceiveBuffer[uint8_t client] (uint8_t* buffer,
                                          unsigned int length,
                                          bool single_use){
    if (sizeof(rxEncoded) < call FEC.encodedLen(length)){
      return ESIZE;
    }
    atomic{
      rxBuf = buffer;
      return call SubRf1aPhysical.setReceiveBuffer[client](rxEncoded,
        call FEC.encodedLen(length), single_use);
    }
  }

  async event void SubRf1aPhysical.receiveDone[uint8_t client] (uint8_t* buffer,
                                unsigned int count,
                                int result){
//    printf("rxd: %u %u\r\n", count, result);
    atomic{
      if (buffer == rxEncoded && rxBuf != NULL){
        //TODO: if we're detecting bit errors at the coding layer, 
        //this is the place to do it. would be something like adding 
        //a pointer to the decode command which would store bit error 
        //calculations. Simplest would be an array of bytes (equal 
        //length to decoded buffer), where the decode process records 
        //the BER estimate for each byte.

        uint8_t decodedLen = call FEC.decode(buffer, rxBuf, count);
        uint8_t decodedPayloadLen = decodedLen - sizeof(uint16_t);
        nx_uint16_t computedCrc; 
        nx_uint16_t decodedCrc;
        uint8_t* rxBufTmp = rxBuf;

        decodedCrc = *((nx_uint16_t*)(rxBuf + decodedPayloadLen));
        computedCrc = call Crc.crc16(rxBuf, decodedPayloadLen);

        //override crcPassed metadata- store result in this
        //component and intercept storeMetadata call. This is
        //more-or-less how it's handled in the phy layer (md is
        //generated but not associated with a message_t until later)
        if (decodedCrc != computedCrc){
          lastCrcPassed = FALSE;
        }else{
          lastCrcPassed = TRUE;
        }
        rxBuf = NULL;
        signal Rf1aPhysical.receiveDone[client](rxBufTmp, decodedLen, result);
      }else{
        //this will happen if we get a failed reception. Leave it to
        //the next layer to deal with the fallout (most likely by
        //supplying the last buffer used in setReceiveBuffer)
        printf("!buffer mismatch: %p != %p or %p == null. Result: %x count %u\r\n",
          buffer, rxEncoded, rxBuf, result, count);
        signal Rf1aPhysical.receiveDone[client](buffer, count, result);
      }
    }
  }

  async command void Rf1aPhysicalMetadata.store (rf1a_metadata_t* metadatap){
    call SubRf1aPhysicalMetadata.store(metadatap);
    //manually set crc pass/fail.
    if (lastCrcPassed){
      metadatap->lqi |= 0x80;
    }else{
      metadatap->lqi &= ~0x80;
    }
  }
  
  async command unsigned int SubRf1aTransmitFragment.transmitReadyCount[uint8_t client](unsigned int count){
    uint8_t rv = (encodedReady < count)? encodedReady:count;
    post encodeAMAP();
    return rv;
  }

  async command const uint8_t* SubRf1aTransmitFragment.transmitData[uint8_t client](unsigned int count){
    uint8_t* txStart = encodedPos;
    uint8_t txrc = call SubRf1aTransmitFragment.transmitReadyCount[client](count);
    encodedPos += txrc;
    encodedReady -= txrc;
    return txStart;
  }

  default async command unsigned int Rf1aTransmitFragment.transmitReadyCount[uint8_t client](unsigned int count){
    return call DefaultRf1aTransmitFragment.transmitReadyCount(count);
  }

  default async command const uint8_t* Rf1aTransmitFragment.transmitData[uint8_t client](unsigned int count){
    return call DefaultRf1aTransmitFragment.transmitData(count);
  }

  //-----------  Pass-throughs and defaults
  async command int Rf1aPhysicalMetadata.rssi (const rf1a_metadata_t* metadatap){
    return call SubRf1aPhysicalMetadata.rssi(metadatap);
  }

  async command int Rf1aPhysicalMetadata.lqi (const rf1a_metadata_t* metadatap){
    return call SubRf1aPhysicalMetadata.lqi(metadatap);
  }

  async command bool Rf1aPhysicalMetadata.crcPassed (const rf1a_metadata_t* metadatap){
    return call SubRf1aPhysicalMetadata.crcPassed(metadatap);
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
