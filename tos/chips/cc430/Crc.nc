//The TOS standard crc interface does not use const pointers, though
//it should. This leads to warnings (fixable only with unsafe casts)
//for cases where we need to perform a CRC over some const buffer. In
//general, there's no reason that performing a CRC should modify the
//data being checksummed, so I think this is the better interface.
interface Crc{
  async command uint16_t crc16(const void* buf, uint8_t len);

  async command uint16_t seededCrc16(uint16_t startCrc, const void* buf, uint8_t len);
}
