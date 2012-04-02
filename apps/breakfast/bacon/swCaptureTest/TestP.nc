module TestP{
  uses interface Boot;
  uses interface Leds;
  uses interface UartStream;
  uses interface StdControl as UartControl;
  uses interface SWCapture;
} implementation {

  event void Boot.booted(){
    call UartControl.start();
    printf("\r\nSW CAPTURE TEST\r\n");
    printf("c: capture time\r\n");
    printf("q: quit/reset\r\n");
    //using the I2C pins, so we have to turn on flash :(
    P2DIR |= BIT1;
    P2OUT |= BIT1;
    atomic{
      PMAPPWD = PMAPKEY;
      PMAPCTL = PMAPRECFG;
      P1MAP3 = PM_SMCLK;
      PMAPPWD = 0x0;
    }
    P1SEL |= BIT3;
    P1SEL &= ~BIT2;
    P1DIR |= BIT2|BIT3;
    printf("[");
  }

  task void capture(){
//    P1OUT ^= BIT2;
    printf("%lu, ", call SWCapture.capture());
  }

  async event void UartStream.receivedByte(uint8_t b){
    switch(b){
      case 'q':
        WDTCTL = 0;
        break;
      case 'c':
        post capture();
        break;
      case '\r':
        printf("\n\r");
        break;
      default:
        printf("%c", b);
    }
  }
  async event void UartStream.sendDone(uint8_t* buf, uint16_t len, error_t err){}
  async event void UartStream.receiveDone(uint8_t* buf, uint16_t len, error_t err){}

}
