 #include "hamming74.h"
module Hamming74FECC{
  provides interface FEC;
}implementation {

  async command uint8_t FEC.encode(const uint8_t* decoded, uint8_t* encoded,
      uint8_t decodedLen){
    uint8_t i;
    for(i=0; i < decodedLen; i++){
      encoded[2*i] = encoding[decoded[i]>>4];
      encoded[(2*i) + 1] = encoding[decoded[i] & 0x0f];
    }
    return 2*decodedLen;
  }

  async command uint8_t FEC.decode(const uint8_t* encoded, uint8_t* decoded, 
      uint8_t encodedLen){
    uint8_t i;
    for (i = 0; i < encodedLen; i++){
      uint8_t d = decoding[encoded[i]];
      if (i&0x01){
        decoded[i>>1] |= d;
      }else{
        decoded[i>>1] = 0xf0 & (d <<4);
      }
    }
    return (encodedLen>>1);
  }

  async command uint8_t FEC.encodedLen(uint8_t rawLen){
    return 2*rawLen;
  }
}
