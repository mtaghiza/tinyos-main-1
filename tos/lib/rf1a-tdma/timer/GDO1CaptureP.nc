#include "msp430_internal_capture.h"

module GDO1CaptureP{
  provides interface GetNow<uint8_t> as GetCCIS;
} implementation {
  //GDO1 is CCIxB for Timer A0 CCR3 according to table 11 (TA0 Signal connections)
  async command uint8_t GetCCIS.getNow(){
    return CCIxB;
  }
}
