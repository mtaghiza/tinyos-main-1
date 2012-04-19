module TestP{
  uses interface Boot;
  uses interface Leds;
  uses interface UartStream;
  uses interface StdControl as UartControl;
  uses interface Read<uint16_t>;
  uses interface Timer<TMilli>;
  uses interface SplitControl ;
} implementation {
  bool keepSampling = FALSE;

  event void SplitControl.startDone(error_t err){
    printf("StartDone\r\n");
  }

  event void SplitControl.stopDone(error_t err){
    printf("StopDone\r\n");
  }

  event void Boot.booted(){
    call UartControl.start();
    call SplitControl.start();
    printf("Photo sensor test\r\n");
    printf("s: Sample\r\n");
    printf("v: toggle power(start/stop)\r\n");
    printf("q: quit/reset\r\n");
  }

  task void sample(){
    printf("Read: %x\r\n", call Read.read());
  }

  task void startSample(){
    printf("Sampling. \r\n");
    keepSampling = TRUE;
    post sample();
  }

  task void stopSample(){
    printf("stop sampling.\r\n");
    keepSampling = FALSE;
    post sample();
  }

  event void Timer.fired(){
    if (keepSampling){
      post sample();
    } else{
      printf("Skip.\r\n");
    }
  }

  event void Read.readDone(error_t err, uint16_t val){
    printf("X R: %x VCC: %x P2.5DIR: %x P2.5SEL: %x P2MAP4: %x Value: %d\r\n", err, 
      0x01 & (PJDIR >>1), 
      0x01 & (P2DIR >>5), 0x01 & (P2SEL >> 5),
      P2MAP4,
      val);
    call Timer.startOneShot(2048);
  }

  async event void UartStream.receivedByte(uint8_t b){
    switch(b){
      case 'q':
        WDTCTL = 0;
        break;
      case 's':
        post startSample();
        break;
      case 'S':
        post stopSample();
        break;
      case 'v':
        if (call SplitControl.start() == EALREADY){
          call SplitControl.stop();
        }
        break;
      case '\r':
        printf("\r\n");
        break;
      default:
        printf("%c", b);
    }
  }
  async event void UartStream.sendDone(uint8_t* buf, uint16_t len, error_t err){}
  async event void UartStream.receiveDone(uint8_t* buf, uint16_t len, error_t err){}

}
