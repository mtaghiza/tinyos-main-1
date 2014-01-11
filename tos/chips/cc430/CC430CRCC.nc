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

module CC430CRCC{
  provides interface Crc;
} implementation {

  async command uint16_t Crc.crc16(const void* buf, uint8_t len){
    return call Crc.seededCrc16(0x0000, buf, len);
  }
  
  #ifndef DUMMY_CRC
  #define DUMMY_CRC 0
  #endif
  #if DUMMY_CRC == 0 
  //FIXME: this will ignore the last byte if an odd number of bytes is
  //provided.
  async command uint16_t Crc.seededCrc16(uint16_t startCrc, const void* buf, uint8_t len){
    uint8_t i; 
    uint16_t nw = 0;
    uint16_t result;
    atomic{
      CRCINIRES = startCrc;
      //TODO: switch to direct word access: cast buf as a uint16_t*
      //and read len/2 elements from it. 
      for (i=0; i< len; i++){
        nw = (nw << 8) | ((uint8_t*)buf)[i];
        if ( i & 0x01){
          CRCDI = nw;
        }
      }
      result = CRCINIRES;
    }
    return result;
  }
  #else
  async command uint16_t Crc.seededCrc16(uint16_t startCrc, const void* buf, uint8_t len){
    return 0;
  }
  #endif
}
