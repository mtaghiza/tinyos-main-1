#include "Rf1a.h"

interface CXTDMA{
  async event rf1a_offmode_t frameType(uint16_t frameNum);

  async event bool getPacket(message_t** msg, uint8_t* len, uint16_t frameNum);
  async event void sendDone(message_t* msg, uint8_t len, 
    uint16_t frameNum, error_t error);

  async event message_t* receive(message_t* msg, uint8_t len, 
    uint16_t frameNum, uint32_t timestamp);

}
