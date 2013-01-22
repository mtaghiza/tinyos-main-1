module CC430CRCC{
  provides interface Crc;
} implementation {

  async command uint16_t Crc.crc16(const void* buf, uint8_t len){
    return call Crc.seededCrc16(0x0000, buf, len);
  }
  
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
}
