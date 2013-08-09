module UartRebooterP{
  uses interface Boot;
  uses interface StdControl as SerialControl;
  uses interface UartStream;
} implementation {
  event void Boot.booted(){
    call SerialControl.start();
  }
  
  uint8_t overflowFun(uint16_t left){
    if (left == 0){
      return 1;
    }else{
      return overflowFun(left-1) * overflowFun(left-1);
    }
  }

  task void overflow(){
    overflowFun(1000);
  }

  async event void UartStream.receivedByte( uint8_t byte )  {
    switch (byte){
      case 'q':
        WDTCTL = 0;
        break;
      case 'o':
        post overflow();
        break;
    }
  }

  async event void UartStream.sendDone( uint8_t* buf, uint16_t len,
    error_t error ) {}
  async event void UartStream.receiveDone( uint8_t* buf, 
    uint16_t len, error_t error ) {}


}
