#include "hamming74.h"

module FECRf1aFifoP{
  provides interface Rf1aFifo;
  uses interface HplMsp430Rf1aIf as Rf1aIf;
} implementation {
  #define FEC_BUF_LEN 64
  uint8_t encodedBuf[FEC_BUF_LEN];

  async command uint8_t Rf1aFifo.getEncodedLen(uint8_t decodedLen){
    return 2*decodedLen;
  }

  async command uint8_t Rf1aFifo.getDecodedLen(uint8_t encodedLen){
    return encodedLen>>1;
  }

  async command error_t Rf1aFifo.readRXFIFO(uint8_t* buf, uint8_t dataBytes, 
      bool isControl){
    if (isControl){
      call Rf1aIf.readBurstRegister(RF_RXFIFORD, buf, dataBytes);
      return SUCCESS;
    } else {
      if (call Rf1aFifo.getEncodedLen(dataBytes) > FEC_BUF_LEN){
        return ESIZE;
      }else{
        uint8_t i;
        call Rf1aIf.readBurstRegister(RF_RXFIFORD, encodedBuf,
          dataBytes*2);
        for (i = 0; i < call Rf1aFifo.getEncodedLen(dataBytes); i++){
          if (i&0x01){
            buf[(i>>1)+1] |= decoding[encodedBuf[i]];
          }else{
            buf[i>>1] = decoding[encodedBuf[i]] << 4;
          }
        }
        return SUCCESS;
      }
    }
  } 

  //We're encoding big-end first: the high order nibble of byte i goes
  //  into the buffer at 2*i, low-order nibble at 1+2*i
  async command error_t Rf1aFifo.writeTXFIFO(const uint8_t* buf, uint8_t dataBytes, 
      bool isControl){
    if (isControl){
      call Rf1aIf.writeBurstRegister(RF_TXFIFOWR, buf,
        dataBytes);
      return SUCCESS;
    } else {
      if (call Rf1aFifo.getEncodedLen(dataBytes) > FEC_BUF_LEN){
        return ESIZE;
      }else{
        uint8_t i;
        for (i=0; i < dataBytes; i++){
          //would like this to be more flexible so we can change the
          //encoding.
          encodedBuf[2*i] = encoding[buf[i] >> 4];
          encodedBuf[(2*i)+1] = encoding[(buf[i] & 0x0f)];
        }
        call Rf1aIf.writeBurstRegister(RF_TXFIFOWR, encodedBuf, 
          call Rf1aFifo.getEncodedLen(dataBytes));
        return SUCCESS;
      }
    }
  }
  
}
