#include "Rf1a.h"

interface CXTDMA{
  event rf1a_offmode_t frameType(uint16_t frameNum);

  event bool getPacket(message_t** msg, uint16_t frameNum);
  event error_t sendDone(message_t* msg, uint8_t len, 
    uint16_t frameNum, error_t error);

  event message_t* receive(message_t* msg, uint8_t len, 
    uint16_t frameNum, uint32_t timestamp);

}
