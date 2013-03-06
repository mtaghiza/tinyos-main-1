
generic module TestP(bool useAlarm, bool useTimer, uint32_t alarmRate){
  uses interface Boot;
  uses interface Alarm<TMicro, uint32_t>;
  uses interface Leds;
  uses interface StdControl;
  uses interface Msp430XV2ClockControl;
} implementation {
  
  task void printConfig(){
    printf("config\r\n");
    //check XT2OFF: if set to 0, then it is permanently running.
    // yes, it was set to 0.
    
    //TODO: UCS registers: SMCLKREQEN, for instance
    //TODO: TA0/TA1 registers
    //TODO: RTC registers
    //TODO: ADC12
    //TODO: USCI modules
    //TODO: watchdog
  }

  task void restartAlarm(){
    printf(".");
    atomic call Alarm.startAt(call Alarm.getAlarm(), alarmRate);
  }

  event void Boot.booted(){
    atomic{
      //power up flash: otherwise, it forces SPI lines to GND
      P2SEL &= ~BIT1;
      P2OUT |=  BIT1;

      //map SMCLK/MCLK to pins
      PMAPPWD = PMAPKEY;
      PMAPCTL = PMAPRECFG;
      //P1.1: SMCLK
      P1MAP1 = PM_SMCLK;
      //P2.4: MCLK
      P2MAP4 = PM_MCLK;
      //P1.3: ACLK
      P1MAP3 = PM_ACLK;
      PMAPPWD = 0x00;
      
      //configure pins to function/output
      P1DIR |= BIT1;
      P1SEL |= BIT1;
      P2DIR |= BIT4;
      P2SEL |= BIT4;
      P1DIR |= BIT3;
      P1SEL |= BIT3;
      //toggle when alarm fires
      P1DIR |= BIT2;
      P1SEL &= ~BIT2;
    }
    call StdControl.start();
    if (useAlarm){
      post restartAlarm();
    } else if (!useTimer){
      call Msp430XV2ClockControl.stopMicroTimer();
    }
    post printConfig();
  }

  async event void Alarm.fired(){
    post restartAlarm();
  }
}
