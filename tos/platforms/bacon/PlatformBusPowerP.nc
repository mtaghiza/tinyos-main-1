 #include "BaconBusPower.h"
module PlatformBusPowerP{
  provides interface Init;
  provides interface SplitControl;
  uses interface GeneralIO as EnablePin;
  uses interface GeneralIO as I2CData;
  uses interface GeneralIO as I2CClk;
  uses interface GeneralIO as Term1WB;
  uses interface Timer<TMilli>;
} implementation {
  bool on = FALSE;
  command error_t Init.init(){
    call Term1WB.makeOutput();
    call Term1WB.clr();
    call I2CData.makeOutput();
    call I2CData.clr();
    call I2CClk.makeOutput();
    call I2CClk.clr();
    call EnablePin.makeOutput();
    call EnablePin.clr();
    return SUCCESS;
  }

  task void startDoneTask(){
    signal SplitControl.startDone(SUCCESS);
  }
  task void stopDoneTask(){
    signal SplitControl.stopDone(SUCCESS);
  }

  command error_t SplitControl.start(){
    if (on){
      return EALREADY;
    }else {
      on = TRUE;
      call Term1WB.makeInput();
      //start powering up the bus over the I2C lines
      //This is a bit of a hack: if we just flip the switch from GND
      //to 3V0, the resulting rush of current browns out the cc430.
      call I2CData.set();
      call I2CClk.set();

      //Ideally, we'd wait until the input to Term1WB was high, but:
      // 1. if there's nothing connected to the bus, this might not
      //    ever happen
      // 2. There may still be a voltage difference of 1.5V when this
      //    occurs
      // So, we just wait some short period of time.
      call Timer.startOneShot(BUS_STARTUP_TIME);
      return SUCCESS;
    }
  }

  event void Timer.fired(){
    // bus should be ready now, flip the switch.
    call EnablePin.set();
    post startDoneTask();
  }

  command error_t SplitControl.stop(){
    if (on){
      on = FALSE;
      call I2CData.clr();
      call I2CClk.clr();
      call Term1WB.makeOutput();
      call Term1WB.clr();
      call EnablePin.clr();
      post stopDoneTask();
      return SUCCESS;
    } else {
      return EALREADY;
    }
  }

  default event void SplitControl.startDone(error_t err){}
  default event void SplitControl.stopDone(error_t err){}
}
