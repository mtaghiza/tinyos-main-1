 #include "StateTimingDebug.h"

module CXRadioStateTimingP{
  provides interface StateTiming;
  uses interface StateTiming as SubStateTiming;
} implementation {
  async command void StateTiming.start(uint8_t state){
//    STATE_TIMING_CAP_TOGGLE_PIN;  
//    printf("c%x\r\n", state);
    //state is in upper nibble, so shift it on over
    if(state == RF1A_S_OFFLINE){
      state = 0x80;
    }
//    if (state == 0x20){
//      STATE_TIMING_TX_SET_PIN;
//    }else{
//      STATE_TIMING_TX_CLEAR_PIN;
//    }
    call SubStateTiming.start( state >> 4);
  }

  async command uint32_t StateTiming.getTotal(uint8_t state){
    return call SubStateTiming.getTotal(state >> 4);
  }

  async command uint32_t StateTiming.getOverflows(uint8_t state){
    return call SubStateTiming.getOverflows(state >> 4);
  }
}
