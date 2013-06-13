module TestP{
  uses interface Boot;
  uses interface UartStream;
  uses interface StdControl as SerialControl;

  uses interface LppControl;
  uses interface SplitControl;
  uses interface Send;
  uses interface Packet;
  uses interface Receive;
  uses interface Pool<message_t>;

  uses interface Leds;
} implementation {

  message_t* txMsg;
  message_t* rxMsg;

  bool started = FALSE;
  task void toggleStartStop();
  
  #ifndef PAYLOAD_LEN 
  #define PAYLOAD_LEN 10
  #endif
  #define SERIAL_PAUSE_TIME 10240UL

  typedef nx_struct test_payload{
    nx_uint8_t body[PAYLOAD_LEN];
    nx_uint32_t timestamp;
  } test_payload_t;


  task void usage(){
    printf("USAGE\r\n");
    printf("-----\r\n");
    printf(" q: reset\r\n");
    printf(" t: transmit packet\r\n");
    printf(" p: toggle probe interval between 1 second and default\r\n");
    printf(" s: sleep\r\n");
    printf(" w: wakeup\r\n");
    printf(" k: kill serial (for 10 seconds)\r\n");
    printf(" S: toggle start/stop\r\n");
  }


  event void Boot.booted(){
    call SerialControl.start();
    printf("Booted\r\n");
    post usage();
    atomic{
      PMAPPWD = PMAPKEY;
      PMAPCTL = PMAPRECFG;
//      //SMCLK to 1.1
      P1MAP1 = PM_SMCLK;
      //GDO to 2.4 (synch)
      P2MAP4 = PM_RFGDO0;
      PMAPPWD = 0x00;

      P1DIR |= BIT1;
      P1SEL &= ~BIT1;
      P1OUT &= ~BIT1;
      P1SEL |= BIT1;
      P2DIR |= BIT4;
      P2SEL |= BIT4;
      
      //power on flash chip
      P2SEL &=~BIT1;
      P2OUT |=BIT1;
      //enable p1.2,3,4 for gpio
      P1DIR |= BIT2 | BIT3 | BIT4;
      P1SEL &= ~(BIT2 | BIT3 | BIT4);
    }
    post toggleStartStop();
  }


  task void sendPacket(){
    if (txMsg){
      printf("still sending\r\n");
    }else{
      cx_link_header_t* header;
      test_payload_t* pl;
      error_t err;
      txMsg = call Pool.get();
      call Packet.clear(txMsg);
      pl = call Packet.getPayload(txMsg, 
        call Packet.maxPayloadLength());
      printf("msg %p pl %p\r\n", txMsg, pl);
      header->destination = AM_BROADCAST_ADDR;
      header->source = TOS_NODE_ID;
      err = call Send.send(txMsg, call Packet.maxPayloadLength());
      printf("Send: %x\r\n", err);
      if (err != SUCCESS){
        call Pool.put(txMsg);
        txMsg = NULL;
      }
    }
  }

  task void sleep(){
    printf("Sleep: %x\r\n", call LppControl.sleep());
  }

  event void SplitControl.startDone(error_t error){ 
    printf("start done: %x pool: %u\r\n", error, call Pool.size());
    started = (error == SUCCESS);
  }
  event void SplitControl.stopDone(error_t error){ 
    printf("stop done: %x pool: %u\r\n", error, call Pool.size());
    started = FALSE;
  }

  event void Send.sendDone(message_t* msg, error_t error){
    call Leds.led0Toggle();
    printf("SD %x\r\n", error);
    if (msg == txMsg){
      call Pool.put(txMsg);
      txMsg = NULL;
    } else{
      printf("mystery packet: %p\r\n", msg);
    }
  }

  task void handleRX(){
    test_payload_t* pl = call Packet.getPayload(rxMsg,
      sizeof(test_payload_t));
    printf("RX %p %p\r\n", rxMsg, pl); 
    call Pool.put(rxMsg);
    rxMsg = NULL;
  }

  event message_t* Receive.receive(message_t* msg, void* pl, uint8_t len){
    if (rxMsg == NULL){
      message_t* ret = call Pool.get();
      if (ret){
        rxMsg = msg;
        post handleRX();
        return ret;
      }else{
        printf("pool empty\r\n");
        return msg;
      }
    }else{
      printf("Busy RX\r\n");
      return msg;
    }
  }


  task void toggleStartStop(){
    if (started){
      call SplitControl.stop();
    }else {
      call SplitControl.start();
    }
  }
  
  task void wakeup(){
    printf("wakeup: %x\r\n", call LppControl.wakeup());
  }

  bool longProbe = TRUE;
  task void setProbeInterval(){
    uint32_t pi;
    error_t error;
    if (longProbe){
      pi = PROBE_INTERVAL;
    }else{
      pi = LPP_DEFAULT_PROBE_INTERVAL;
    }
    error = call LppControl.setProbeInterval(pi);
    if (error == SUCCESS){
      longProbe = (pi == LPP_DEFAULT_PROBE_INTERVAL);
    }
    printf("SPI %lu: %x\r\n", pi, error);
  }

  async event void UartStream.receivedByte(uint8_t byte){ 
     switch(byte){
       case 'q':
         WDTCTL = 0;
         break;
       case 't':
         post sendPacket();
         break;
       case 's':
         post sleep();
         break;
       case 'p':
         post setProbeInterval();
         break;
       case 'w':
         post wakeup();
         break;
       case '?':
         post usage();
         break;
       case '\r':
         printf("\n");
         break;
       default:
         break;
     }
     printf("%c", byte);
  }

  async event void UartStream.receiveDone( uint8_t* buf, uint16_t len,
    error_t error ){}
  async event void UartStream.sendDone( uint8_t* buf, uint16_t len,
    error_t error ){}
}
