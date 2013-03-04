#include "FECDebug.h"

module DoubleRf1aFifoP{
  provides interface Rf1aFifo;
  uses interface HplMsp430Rf1aIf as Rf1aIf;
  uses interface Crc;
} implementation {
  uint8_t dummyLookup[1] = {0};
  #define FEC_BUF_LEN 64
  uint8_t encodedBuf[FEC_BUF_LEN];
  async command uint8_t Rf1aFifo.getCrcLen(){
    return 4;
  }
  async command bool Rf1aFifo.crcOverride(){
    return TRUE;
  }
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
//      printf_FEC("R %u %x\r\n", dataBytes, *buf);
      return SUCCESS;
    } else {
      if (call Rf1aFifo.getEncodedLen(dataBytes) + call Rf1aFifo.getCrcLen() > FEC_BUF_LEN){
        return ESIZE;
      }else{
        uint8_t i;
        error_t ret = SUCCESS;
//        printf_FEC("[ ");
        call Rf1aIf.readBurstRegister(RF_RXFIFORD, encodedBuf,
          call Rf1aFifo.getEncodedLen(dataBytes) + call Rf1aFifo.getCrcLen());
        for (i = 0; i < call Rf1aFifo.getEncodedLen(dataBytes) + call Rf1aFifo.getCrcLen(); i++){
//          printf_FEC("%02X ", encodedBuf[i]);
          if (i&0x01){
            
            buf[i>>1] = encodedBuf[i] + dummyLookup[0];
//            printf_FEC("%02X ", buf[i>>1]);
          }else{
            buf[i>>1] = encodedBuf[i] + dummyLookup[0];
          }
        }

        if (ret == SUCCESS){
          //god byte alignment is the worst
          uint16_t receivedCrc = buf[dataBytes]| buf[dataBytes+1]<<8;
          uint16_t cc = call Crc.crc16(buf, dataBytes);
//          printf_FEC("RC %x CC %x\r\n", receivedCrc, cc);
          if( receivedCrc != cc){
            ret = FAIL;
          }
        }

//        printf_FEC("]\r\n");
        return ret;
      }
    }
  } 

  //We're encoding big-end first: the high order nibble of byte i goes
  //  into the buffer at 2*i, low-order nibble at 1+2*i
  async command error_t Rf1aFifo.writeTXFIFO(const uint8_t* buf, uint8_t dataBytes, 
      bool isControl){
//    printf_FEC("W %u %x\r\n", dataBytes, isControl);
    if (isControl){
      call Rf1aIf.writeBurstRegister(RF_TXFIFOWR, buf,
        dataBytes);
      if (dataBytes == 1){
//        printf_FEC("Wc %x\r\n", *buf);
      }
      return SUCCESS;
    } else {
      if (call Rf1aFifo.getEncodedLen(dataBytes) + call Rf1aFifo.getCrcLen() > FEC_BUF_LEN){
        return ESIZE;
      }else{
        uint8_t i;
        uint16_t crc;
        uint8_t* crcb=(uint8_t*)&crc;
        for (i=0; i < dataBytes; i++){
          //would like this to be more flexible so we can change the
          //encoding.
          encodedBuf[2*i] = (dummyLookup[0]>>4) + buf[i];
          encodedBuf[(2*i)+1] = (dummyLookup[0]&0x0f) + buf[i];
        }
        crc = call Crc.crc16((uint8_t*)buf, dataBytes);
//        printf_FEC("WC %x\r\n", crc);
        for (i=0; i < sizeof(uint16_t); i++){
          //would like this to be more flexible so we can change the
          //encoding.
          encodedBuf[call Rf1aFifo.getEncodedLen(dataBytes)+2*i] = (dummyLookup[0]>>4) + crcb[i];
          encodedBuf[call Rf1aFifo.getEncodedLen(dataBytes)+(2*i)+1] = (dummyLookup[0]&0x0f) + crcb[i];
        }
        call Rf1aIf.writeBurstRegister(RF_TXFIFOWR, encodedBuf, 
          call Rf1aFifo.getEncodedLen(dataBytes) + call Rf1aFifo.getCrcLen());
        
        return SUCCESS;
      }
    }
  }
  
}

