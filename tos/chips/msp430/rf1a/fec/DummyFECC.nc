module DummyFECC{
  provides interface FEC;
} implementation{
  async command uint8_t FEC.encode(const uint8_t* decoded, uint8_t* encoded,
      uint8_t decodedLen){
    uint8_t i;
    for(i=0; i < decodedLen; i++){
      encoded[i] = decoded[i];
    }
    return decodedLen;
  }

  async command uint8_t FEC.decode(const uint8_t* encoded, uint8_t* decoded, 
      uint8_t encodedLen){
    uint8_t i;
    for (i = 0; i < encodedLen; i++){
      decoded[i] = encoded[i];
    }
    return encodedLen;
  }

  async command uint8_t FEC.encodedLen(uint8_t rawLen){
    return rawLen;
  }
}
