module TestP{
  uses interface Boot;
  uses interface Leds;
  uses interface UartStream;
  uses interface StdControl as UartControl;
  uses interface Crc;
  uses interface Timer<TMilli>;
} implementation {
  bool keepSampling = FALSE;
  const char* test_string = "Hello Checksum.";

  event void Timer.fired(){}

  event void Boot.booted(){
    call UartControl.start();
    printf("CHECKSUM tester\r\n");
    printf(" c: compute \r\n");
    printf("---------------\r\n");
  }

  task void compute(){
    printf("result: %x\r\n", call Crc.crc16((void*)test_string, 8));
  }

  async event void UartStream.receivedByte(uint8_t b){
    switch(b){
      case 'q':
        WDTCTL = 0;
        break;
      case 'c':
        post compute();
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
