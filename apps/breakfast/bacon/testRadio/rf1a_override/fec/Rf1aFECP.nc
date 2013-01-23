
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
    //driver calls txReadyCount, then transmitData
    //semantics of txReadyCount: from current position (e.g. position
    //you're about to return)
    //This is OK because in practice, we only call txReadyCount and
    //transmitData from within the same atomic block.

    //TODO: make sure that all of these are safe with a duplicate task
    //post/no change in how much is ready.

    //find out how much data is available (max dictated by initial
    //send length/encoded length param)
    uint8_t rawReady 
      = call Rf1aTransmitFragment.transmitReadyCount[txClient](rawLen - encodedSoFar);
    uint8_t* epLocal;

    //get pointer to start of ready data
    const uint8_t* rawPos = call Rf1aTransmitFragment.transmitData[txClient](rawReady); 

    atomic{
      epLocal = encodedPos;
    }

//    printf("amap %p (%p) r=%p rr=%u\r\n", 
//      epLocal, txEncoded, rawPos, rawReady);
    //encode whatever's now ready, update position in encoded buffer
    encodedReady += call FEC.encode(
      rawPos,
      epLocal,
      rawReady
    );
    encodedSoFar += rawReady;

    //update runningCRC from just-provided data
    runningCRC = call Crc.seededCrc16(runningCRC, rawPos,
      rawReady);

//    {
//      uint8_t i;
//      for (i = 0; i < 128; i++){
//        printf("%x ", txEncoded[i]);
//      }
//      printf("\r\n");
//    }

    //append CRC if we're done and haven't done so yet. 
    if (rawLen - encodedSoFar == 0 && !crcAppended){
      //using nx types ensures that byte alignment is not a problem.
      nx_uint16_t* crcDest = (nx_uint16_t*)(epLocal + call FEC.encodedLen(rawLen));
      nx_uint16_t nxCrc;
      nxCrc = runningCRC;
      encodedReady += sizeof(runningCRC);

//      printf("crc=%x @%p (%p + %x)\r\n", 
//        runningCRC, crcDest, epLocal,
//        call FEC.encodedLen(rawLen));
      *crcDest = nxCrc;
      crcAppended = TRUE;
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
      printf("fec.s %p %u\r\n", buffer, length);
      {
        uint8_t i;
        for (i = 0; i < length; i++){
          printf("%x ", buffer[i]);
        }
        printf("\r\n");
      }

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
  
      //get encoded length: make sure to include CRC!
      encodedLen = call FEC.encodedLen(length + sizeof(runningCRC));
      printf("L %u -> %u\r\n", length, encodedLen);
  
      //pass it down
      atomic{
        err  = call SubRf1aPhysical.send[client](encodedPos, encodedLen);
        sendOutstanding =  (err == SUCCESS);
      }
      return err;
    }
  }

  async event void SubRf1aPhysical.sendDone[uint8_t client] (int result){
    sendOutstanding = FALSE;
//    printf("TXD %x\r\n", result);
    signal Rf1aPhysical.sendDone[client](result);
  }

  async command error_t Rf1aPhysical.setReceiveBuffer[uint8_t client] (uint8_t* buffer,
                                          unsigned int length,
                                          bool single_use){
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
        uint8_t decodedLen = call FEC.decode(buffer, rxBuf, count);
        uint8_t decodedPayloadLen = decodedLen - sizeof(uint16_t);
        nx_uint16_t computedCrc; 
        nx_uint16_t decodedCrc;
        uint8_t* rxBufTmp = rxBuf;

        decodedCrc = *((nx_uint16_t*)(rxBuf + decodedPayloadLen));
        computedCrc = call Crc.crc16(rxBuf, decodedPayloadLen);
      {
        uint8_t i;
        printf("encoded (%u) ", count);
        for (i = 0; i < count; i++){
          printf("%x ", buffer[i]);
        }
        printf("\r\n");
      }
      {
        uint8_t i;
        printf("decoded (%u) ", decodedLen);
        for (i = 0; i < decodedLen; i++){
          printf("%x ", rxBuf[i]);
        }
        printf("\r\n");
      }
      printf("dc %x cc %x\r\n", decodedCrc, computedCrc);

        //override crcPassed metadata- store result in this
        //component and intercept storeMetadata call 
        if (decodedCrc != computedCrc){
          printf("crc fail\r\n");
          lastCrcPassed = FALSE;
        }else{
          printf("crc pass\r\n");
          lastCrcPassed = TRUE;
        }
        rxBuf = NULL;
        signal Rf1aPhysical.receiveDone[client](rxBufTmp, decodedLen, result);
      }else{
        printf("!buffer mismatch: %p != %p or %p == null\r\n",
          buffer, rxEncoded, rxBuf);
      }
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
  
  async command unsigned int SubRf1aTransmitFragment.transmitReadyCount[uint8_t client](unsigned int count){
    uint8_t rv = (encodedReady < count)? encodedReady:count;
//    printf("strc: %u\r\n", rv);
    post encodeAMAP();
    return rv;
  }

  async command const uint8_t* SubRf1aTransmitFragment.transmitData[uint8_t client](unsigned int count){
    uint8_t* txStart = encodedPos;
    uint8_t txrc = call SubRf1aTransmitFragment.transmitReadyCount[client](count);
//    printf("stxd\r\n");
    encodedPos += txrc;
    encodedReady -= txrc;
    return txStart;
  }

  default async command unsigned int Rf1aTransmitFragment.transmitReadyCount[uint8_t client](unsigned int count){
//    printf("trc\r\n");
    return call DefaultRf1aTransmitFragment.transmitReadyCount(count);
  }

  default async command const uint8_t* Rf1aTransmitFragment.transmitData[uint8_t client](unsigned int count){
//    printf("txd\r\n");
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
//    printf("rxs\r\n");
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
