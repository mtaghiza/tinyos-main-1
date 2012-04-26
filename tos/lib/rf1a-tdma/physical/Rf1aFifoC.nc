module Rf1aFifoC {
  provides interface Rf1aFifo;
  uses interface HplMsp430Rf1aIf as Rf1aIf;
} implementation {
  async command uint8_t Rf1aFifo.getDecodedLen(uint8_t encodedLen){return encodedLen;}
  async command uint8_t Rf1aFifo.getEncodedLen(uint8_t decodedLen){return decodedLen;}

  async command error_t Rf1aFifo.readRXFIFO(uint8_t* buf, uint8_t dataBytes, 
      bool isControl){
    call Rf1aIf.readBurstRegister(RF_RXFIFORD, buf, dataBytes);
    return SUCCESS;
  }
  async command error_t Rf1aFifo.writeTXFIFO(const uint8_t* buf, uint8_t dataBytes, 
      bool isControl){
    call Rf1aIf.writeBurstRegister(RF_TXFIFOWR, buf, dataBytes);
    return SUCCESS;
  }
}
