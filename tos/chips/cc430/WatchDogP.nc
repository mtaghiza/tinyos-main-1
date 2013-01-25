module WatchDogP{
  provides interface Init;
  uses interface Timer<TMilli>;
} implementation{
  command error_t Init.init(){
    atomic{
      WDTCTL = (WDTPW | WDTHOLD);
      //set up using ACKL/512: 16 seconds at 32KHz
//      WDTCTL = (WDTPW | WDTSSEL__ACLK | WDTIS__512K);
      //32K: 1 second
      WDTCTL = (WDTPW | WDTSSEL__ACLK | WDTIS__32K);
      call Timer.startPeriodic(512);
    }
    return SUCCESS;
  }

  event void Timer.fired(){
    //write to WDTCNTCL: must use PW in upper byte
    WDTCTL = (WDTPW | (0x00FF & (WDTCTL | WDTCNTCL)));
  }
}
