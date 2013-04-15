
generic module Rf1aFECP () {
  provides interface Rf1aPhysical;
  provides interface Rf1aPhysicalMetadata;

  uses interface Rf1aPhysical as SubRf1aPhysical;
  uses interface Rf1aPhysicalMetadata as SubRf1aPhysicalMetadata;

  uses interface Rf1aTransmitFragment;
  provides interface Rf1aTransmitFragment as SubRf1aTransmitFragment;
  
  uses interface Rf1aTransmitFragment as DefaultRf1aTransmitFragment;
  uses interface SetNow<uint8_t> as DefaultLength;
  uses interface SetNow<const uint8_t*> as DefaultBuffer;
  uses interface FEC;
  uses interface Crc;
} implementation {
  
  uint8_t* lastBuffer_d;
  typedef struct amap_trace {
    //start of task
    uint8_t rawLen_d;
    uint8_t rawReady_d;
    const uint8_t* rawPos_d;
    const uint8_t* epLocal_e;
    uint8_t encodedReady0_e;
    uint8_t parity;

    //post parity-fix
    bool pf;
    uint8_t rawReady0_d;
    uint8_t numEncoded0_e;
    uint8_t encodedSoFar0_d;
    uint8_t parity0;

    //post parity stash
    bool ps;
    uint8_t rawReady1_d;
    uint8_t parity1;

    //post encode main
    uint8_t numEncoded1_e;
    uint8_t encodedSoFar1_d;

    //post final parity fix
    bool fpf;
    uint8_t numEncoded2_e;
    uint8_t encodedSoFar2_d;

    //crc application
    uint8_t numEncoded3_e;
    //end of task
    uint8_t encodedReady1_e;
  } amap_trace_t;
  uint8_t numTraces = 0;
  amap_trace_t traces[10];

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
  
  //TODO: throw an error if the encoded length of body + header > 255 bytes.
  uint8_t txEncoded_e[2*sizeof(message_t)];
  uint8_t rxEncoded_e[2*sizeof(message_t)];
  
  uint8_t* rxBuf_d;
  
  //write to sendOutstanding in SendDone is safe: will only get this
  //in response to send (with SUCCESS), and the call to Send + set of
  //sendOutstanding is done atomically
  norace bool sendOutstanding;

  bool lastCrcPassed;
  
  //pointer to beginning of encoded + ready data
  uint8_t* encodedPos_e;
  //indicate how many bytes (starting at encodedPos) are available for
  //transmission
  uint8_t encodedReady_e;
  
  //total length of raw data, number of raw bytes already encoded.
  uint8_t rawLen_d;
  uint8_t encodedSoFar_d;

  //the CRC of the currently-transmitting packet (updated as the raw
  //data is encoded)
  uint16_t runningCRC_d;
  bool crcAppended;
  
  //CRC module only operates on 16-bit chunks, so if we have to stop
  //at a non-word boundary, we need to properly handle this.
  enum{ 
    EVEN = 0,
    ODD = 1,
  };
  uint8_t parityFix_d[2];
  uint8_t parity = EVEN;
  
  amap_trace_t* nextTrace(){
    amap_trace_t* ret = &traces[numTraces];
    numTraces++;
    return ret;
  }
  
  //encode as much as possible from the current transmitter, updating
  //encodedReady/rawReady etc as needed.
  task void encodeAMAP(){
    uint8_t rawReady_d 
      = call Rf1aTransmitFragment.transmitReadyCount(rawLen_d -
        encodedSoFar_d);
    uint8_t* epLocal_e;
    uint8_t numEncoded_e = 0;
    amap_trace_t* trace = nextTrace();

    //get pointer to start of ready data
    const uint8_t* rawPos_d = 
      call Rf1aTransmitFragment.transmitData(rawReady_d); 

    //stash current encodedPos in case we get interrupted during this
    //process
    atomic{
      epLocal_e = encodedPos_e + encodedReady_e;
      trace -> encodedReady0_e = encodedReady_e; 
    }
    trace -> rawLen_d = rawLen_d;
    trace -> rawReady_d = rawReady_d;
    trace -> rawPos_d = rawPos_d;
    trace -> epLocal_e = epLocal_e;
    trace -> parity = parity;

    //parity is odd: we have an outstanding un-encoded byte. Encode
    //that + the first byte that was just provided.
    if (parity == ODD && rawReady_d > 0){
      parityFix_d[1] = rawPos_d[0];
      numEncoded_e += call FEC.encode(
        parityFix_d,
        epLocal_e + numEncoded_e,
        2);
      encodedSoFar_d += 2;
      rawPos_d = &rawPos_d[1];
      //update the CRC with these two bytes
      runningCRC_d = call Crc.seededCrc16(runningCRC_d, parityFix_d,
        2);
      rawReady_d -= 1;
      parity = EVEN;
      trace->pf = TRUE;
    }
    trace -> rawReady0_d = rawReady_d;
    trace -> numEncoded0_e = numEncoded_e;
    trace -> encodedSoFar0_d = encodedSoFar_d;
    trace -> parity0 = parity;

    //At this point, either parity is even or there is no data ready,
    //and the CRC should be consistent with what's encoded so far.
    if (rawReady_d){
      if (rawReady_d % 2){
        //odd number of bytes available: parity will become ODD and we
        //need to stash the last byte
        rawReady_d -= 1;
        parityFix_d[0] = rawPos_d[rawReady_d];
        parity = ODD;
        trace -> ps = TRUE;
      }
      trace -> rawReady1_d = rawReady_d;
      trace -> parity1 = parity;

      //encode whatever's now ready, update info about how much is
      //encoded.
      numEncoded_e += call FEC.encode(
        rawPos_d,
        epLocal_e + numEncoded_e,
        rawReady_d
      );
      encodedSoFar_d += rawReady_d;
      //update runningCRC with just-provided data
      runningCRC_d = call Crc.seededCrc16(runningCRC_d, rawPos_d,
        rawReady_d);
    }

    trace -> numEncoded1_e = numEncoded_e;
    trace -> encodedSoFar1_d = encodedSoFar_d;

    //At this point, there's a few possibilities
    // - Parity is EVEN, raw == encoded: append the CRC
    // - Parity is ODD, raw == encoded - 1: the last data byte is
    //   sitting at parityFix[0], and needs to be CRC'ed with dummy
    //   byte, then CRC needs to be appended.
    // - otherwise: we're not at the end yet.
    if (!crcAppended){
      bool needsAppend;
      if (rawLen_d == encodedSoFar_d && parity == EVEN){
        needsAppend = TRUE;
      } else if (rawLen_d == encodedSoFar_d + 1 && parity == ODD){
        //all the data has been encoded except for the last byte.
        //put dummy byte into second position, encode, CRC, and append
        parityFix_d[1] = 0x00;
        numEncoded_e += call FEC.encode(
          parityFix_d,
          epLocal_e + numEncoded_e,
          2);
        encodedSoFar_d += 2;
        runningCRC_d = call Crc.seededCrc16(runningCRC_d, 
          parityFix_d, 2);
        needsAppend = TRUE;
        trace->fpf = TRUE;
      } else {
        //not done yet, so carry on.
        needsAppend = FALSE;
      }
      trace -> numEncoded2_e = numEncoded_e;
      trace -> encodedSoFar2_d = encodedSoFar_d;

      if (needsAppend){
        nx_uint16_t nxCRC_d;
        nxCRC_d = runningCRC_d;
        numEncoded_e += call FEC.encode((const uint8_t*)(&nxCRC_d), 
          epLocal_e + numEncoded_e,
          sizeof(nxCRC_d));
        crcAppended = TRUE;
      }
    }
    trace -> numEncoded3_e = numEncoded_e;

    //now that we're done with this chunk, update the amount of
    //encoded data available.
    atomic{
      encodedReady_e += numEncoded_e;
      trace->encodedReady1_e = encodedReady_e;
    }
  }

  command error_t Rf1aPhysical.send (uint8_t* buffer_d,
      unsigned int length_d, rf1a_offmode_t offMode){
    atomic{
      if (sendOutstanding){
        return EBUSY;
      }
    }
    {
      error_t err;
      uint8_t encodedLen_e;

      atomic {
        //setup for transmission: initialize vars, save client
        encodedPos_e = txEncoded_e;
        encodedSoFar_d = 0; 
        encodedReady_e = 0;
        runningCRC_d = 0;
        //pad length so that it's always even (address CRC computation
        //issue.
        encodedLen_e = call FEC.encodedLen(length_d + (length_d%2)+ sizeof(runningCRC_d));
        numTraces = 0;
      }
      crcAppended = FALSE;
      rawLen_d = length_d;
      lastBuffer_d = buffer_d;
      atomic{
        //hmm... I only want to wire this in if there's nothing
        //  connected to the real R1aFragment interface.
        call DefaultBuffer.setNow(buffer_d);
        call DefaultLength.setNow(length_d);
      }
      parity = EVEN;
      post encodeAMAP();
    
    
      //start up the phy layer's transmission
      atomic{
        err  = call SubRf1aPhysical.send(encodedPos_e,
          encodedLen_e, offMode);
        sendOutstanding =  (err == SUCCESS);
      }
      return err;
    }
  }

  async event void SubRf1aPhysical.sendDone(int result){
    //TODO: debug put this back in
    sendOutstanding = FALSE;
    signal Rf1aPhysical.sendDone(result);
  }

  async command error_t Rf1aPhysical.setReceiveBuffer(
      uint8_t* buffer_d, unsigned int length_d, bool single_use){
    if (sizeof(rxEncoded_e) < call FEC.encodedLen(length_d)){
      return ESIZE;
    }
    atomic{
      rxBuf_d = buffer_d;
      return call SubRf1aPhysical.setReceiveBuffer(rxEncoded_e,
        call FEC.encodedLen(length_d), single_use);
    }
  }

  async event void SubRf1aPhysical.receiveDone(uint8_t* buffer_e,
                                unsigned int count_e,
                                int result){
//    printf("rxd: %u %u\r\n", count, result);
    atomic{
      if (buffer_e == rxEncoded_e && rxBuf_d != NULL){
        //TODO: if we're detecting bit errors at the coding layer, 
        //this is the place to do it. would be something like adding 
        //a pointer to the decode command which would store bit error 
        //calculations. Simplest would be an array of bytes (equal 
        //length to decoded buffer), where the decode process records 
        //the BER estimate for each byte.

        uint8_t decodedLen_d = call FEC.decode(buffer_e, 
          rxBuf_d, count_e);
        uint8_t decodedPayloadLen_d = decodedLen_d - sizeof(uint16_t);
        nx_uint16_t computedCrc_d; 
        nx_uint16_t decodedCrc_d;
        uint8_t* rxBufTmp_d = rxBuf_d;

        decodedCrc_d = *((nx_uint16_t*)(rxBuf_d + decodedPayloadLen_d));
        computedCrc_d = call Crc.crc16(rxBuf_d, decodedPayloadLen_d);

        //override crcPassed metadata- store result in this
        //component and intercept storeMetadata call. This is
        //more-or-less how it's handled in the phy layer (md is
        //generated but not associated with a message_t until later)
        if (decodedCrc_d != computedCrc_d){
          lastCrcPassed = FALSE;
        }else{
          lastCrcPassed = TRUE;
        }
//        {
//          uint8_t i;
//          printf("RX %x %x\r\n[", decodedCrc_d, computedCrc_d);
//          for (i=0; i < count_e; i++){
//            printf("%x ", rxEncoded_e[i]);
//          }
//          printf("]\r\n");
//        }
        rxBuf_d = NULL;
        signal Rf1aPhysical.receiveDone(rxBufTmp_d,
          decodedPayloadLen_d, result);
      }else{
        //this will happen if we get a failed reception. Leave it to
        //the next layer to deal with the fallout (most likely by
        //supplying the last buffer used in setReceiveBuffer)
//        printf("!buffer mismatch: %p != %p or %p == null. Result: %x count %u\r\n",
//          buffer, rxEncoded, rxBuf, result, count);
        signal Rf1aPhysical.receiveDone(buffer_e, count_e, result);
      }
    }
  }

  async command void Rf1aPhysicalMetadata.store (rf1a_metadata_t* metadatap){
    atomic{
      call SubRf1aPhysicalMetadata.store(metadatap);
      //manually set crc pass/fail.
      if (lastCrcPassed){
        metadatap->lqi |= 0x80;
      }else{
        metadatap->lqi &= ~0x80;
      }
    }
  }
  
  async command unsigned int SubRf1aTransmitFragment.transmitReadyCount(unsigned int count){
    uint8_t rv = (encodedReady_e < count)? encodedReady_e:count;
    post encodeAMAP();
    return rv;
  }

  async command const uint8_t* SubRf1aTransmitFragment.transmitData(unsigned int count){
    uint8_t* txStart_e = encodedPos_e;
    uint8_t txrc_e = call SubRf1aTransmitFragment.transmitReadyCount(count);
    encodedPos_e += txrc_e;
    encodedReady_e -= txrc_e;
    return txStart_e;
  }

  default async command unsigned int Rf1aTransmitFragment.transmitReadyCount(unsigned int count){
    return call DefaultRf1aTransmitFragment.transmitReadyCount(count);
  }

  default async command const uint8_t* Rf1aTransmitFragment.transmitData(unsigned int count){
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


  async command error_t Rf1aPhysical.startTransmission(
      bool check_cca, bool targetFSTXON){
    return call SubRf1aPhysical.startTransmission(check_cca, 
      targetFSTXON);
  }

  async command error_t Rf1aPhysical.startReception (){
    return call SubRf1aPhysical.startReception();
  }

  async command error_t Rf1aPhysical.resumeIdleMode
  (rf1a_offmode_t offMode){
    return call SubRf1aPhysical.resumeIdleMode(offMode);
  }

  async command error_t Rf1aPhysical.sleep(){
    return call SubRf1aPhysical.sleep();
  }

  async command int Rf1aPhysical.getChannel (){
    return call SubRf1aPhysical.getChannel();
  }
  async command int Rf1aPhysical.setChannel (uint8_t channel){
    return call SubRf1aPhysical.setChannel(channel);
  }
  async command int Rf1aPhysical.rssi_dBm (){
    return call SubRf1aPhysical.rssi_dBm();
  }
  async command void Rf1aPhysical.readConfiguration(rf1a_config_t* config){
    return call SubRf1aPhysical.readConfiguration(config);
  }
  async command int Rf1aPhysical.enableCca(){
    return call SubRf1aPhysical.enableCca();
  }
  async command int Rf1aPhysical.disableCca(){
    return call SubRf1aPhysical.disableCca();
  }
  async command void Rf1aPhysical.reconfigure(){
    call SubRf1aPhysical.reconfigure();
  }

  async event void SubRf1aPhysical.receiveStarted (unsigned int length){
    signal Rf1aPhysical.receiveStarted(length);
  }

  async event void SubRf1aPhysical.receiveBufferFilled(uint8_t* buffer,
                                        unsigned int count){
    signal Rf1aPhysical.receiveBufferFilled(buffer, count);
  }

  async event void SubRf1aPhysical.frameStarted(){
    signal Rf1aPhysical.frameStarted();
  }
  
  async event void SubRf1aPhysical.clearChannel(){
    signal Rf1aPhysical.clearChannel( );
  }

  async event void SubRf1aPhysical.carrierSense(){
    signal Rf1aPhysical.carrierSense( );
  }

  async event void SubRf1aPhysical.released(){
    signal Rf1aPhysical.released( );
  }
}
