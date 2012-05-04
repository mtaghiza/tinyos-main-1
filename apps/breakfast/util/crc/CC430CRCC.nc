module CC430CRCC{
  provides interface Crc;
} implementation {

  async command uint16_t Crc.crc16(void* buf, uint8_t len){
    return call Crc.seededCrc16(0x0000, buf, len);
  }

  async command uint16_t Crc.seededCrc16(uint16_t startCrc, void* buf, uint8_t len){
    uint8_t i; 
    uint16_t nw = 0;
    uint16_t result;
    atomic{
      CRCINIRES = startCrc;
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
