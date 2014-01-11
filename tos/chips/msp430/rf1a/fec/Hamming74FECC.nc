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


 #include "hamming74.h"
// #include "hamming74Debug.h"
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
