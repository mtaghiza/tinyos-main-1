
 #include <stdio.h>
module SnifferP @safe() {
  uses {
    interface Leds;
    interface Boot;
    interface Timer<TMilli> as MilliTimer;
    interface SplitControl as AMControl;
  }
  uses interface Rf1aPhysical;
  uses interface Rf1aDumpConfig;
  uses interface StdControl as SerialControl;
}
implementation {
  event void MilliTimer.fired(){
    printf(".");
  }

  event void Boot.booted() {
    printf("Booted\r\n");
    P1SEL |= BIT2;
    P1DIR |= BIT2;
    atomic{
      PMAPPWD = PMAPKEY;
      PMAPCTL = PMAPRECFG;
      P1MAP2 = PM_RFGDO0;
      PMAPPWD = 0x00;
    }
    
    call SerialControl.start();
    call AMControl.start();
//    call MilliTimer.startPeriodic(1024);
  }
  event void AMControl.startDone(error_t error){
    rf1a_config_t config;
    printf("Started\r\n");
    call Rf1aPhysical.setChannel(TEST_CHANNEL);
    call Rf1aPhysical.readConfiguration(&config);
    call Rf1aDumpConfig.display(&config);
  }
  event void AMControl.stopDone(error_t error){
  }

  async event void Rf1aPhysical.sendDone (int result) { }
  async event void Rf1aPhysical.receiveStarted (unsigned int length) { }
  async event void Rf1aPhysical.receiveDone (uint8_t* buffer,
                                             unsigned int count,
                                             int result) { }
  async event void Rf1aPhysical.receiveBufferFilled (uint8_t* buffer,
                                                     unsigned int count) { }
  async event void Rf1aPhysical.frameStarted () { }
  async event void Rf1aPhysical.clearChannel () { }
  async event void Rf1aPhysical.carrierSense () { }
  async event void Rf1aPhysical.released () { }
}
