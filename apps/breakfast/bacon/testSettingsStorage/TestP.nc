module TestP{
  uses interface SplitControl;
  uses interface StdControl;
  uses interface Boot;
} implementation {
  event void Boot.booted(){
    call StdControl.start();
    printf("booted.\r\n");
    call SplitControl.start();
    atomic{
      //set up SFD GDO on 1.2
      PMAPPWD = PMAPKEY;
      PMAPCTL = PMAPRECFG;
      P1MAP2 = PM_RFGDO0;
      PMAPPWD = 0x00;

      P2SEL &=~BIT1;
      P2OUT |=BIT1;
    }
  }

  event void SplitControl.startDone(error_t e){
    printf("radio started: %x\r\n", e);
  }

  event void SplitControl.stopDone(error_t e){}
}
