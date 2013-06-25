module TestP{
  uses interface Boot;
  uses interface UartStream;
  uses interface StdControl as SerialControl;

  uses interface SplitControl;
  uses interface CXLink;
  uses interface Send;
  uses interface Packet;
  uses interface CXLinkPacket;
  uses interface Receive;
  uses interface Pool<message_t>;
  uses interface Timer<TMilli>;

  uses interface Leds;
  uses interface Rf1aStatus;
} implementation {

  message_t* txMsg;
  message_t* rxMsg;

  uint8_t packetLength=1;
  uint8_t channel = 32;

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

  task void getStatus(){
    printf("* Radio Status: %x\r\n", call Rf1aStatus.get());
  }

  task void usage(){
    printf("USAGE\r\n");
    printf("-----\r\n");
    printf(" q: reset\r\n");
    printf(" r: receive packet\r\n");
    printf(" R: receive packet, no fwd\r\n");
    printf(" C: (check) receive with 1 second timeout\r\n");
    printf(" t: transmit packet\r\n");
    printf(" T: transmit packet, no retx\r\n");
    printf(" c: switch to next channel\r\n");
    printf(" l: toggle between 1-byte payload or max-len payload\r\n");
    printf(" s: sleep\r\n");
    printf(" k: kill serial (for 10 seconds)\r\n");
    printf(" S: toggle start/stop\r\n");
    post getStatus();
  }

  task void killSerial(){
    call SerialControl.stop();
    call Timer.startOneShot(SERIAL_PAUSE_TIME);
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

  void setChannel(){
    printf("set channel: %u %x\r\n", 
      channel,
      call Rf1aPhysical.setChannel(channel));
  }

  task void receivePacket(){ 
    setChannel();
    printf("RX: %x\r\n",
      call CXLink.rx(0xFFFFFFFF, TRUE));
  }

  task void receivePacketNoRetx(){ 
    setChannel();
    printf("RXn: %x\r\n",
      call CXLink.rx(0xFFFFFFFF, FALSE));
  }
  task void receivePacketShort(){
    setChannel();
    printf("RXs: %x\r\n",
      call CXLink.rx(6500000UL, TRUE));
  }

  void doSendPacket(bool retx){
    setChannel();
    if (txMsg){
      printf("still sending\r\n");
    }else{
      cx_link_header_t* header;
      test_payload_t* pl;
      error_t err;
      txMsg = call Pool.get();
      call Packet.clear(txMsg);
      header = call CXLinkPacket.getLinkHeader(txMsg);
//      pl = call Packet.getPayload(txMsg, sizeof(test_payload_t));
      pl = call Packet.getPayload(txMsg, 
        call Packet.maxPayloadLength());
      printf("msg %p header %p pl %p md %p sn %u\r\n",
        txMsg,
        header,
        pl,
        call CXLinkPacket.getLinkMetadata(txMsg),
        header->sn);
      header->ttl = 1;
      header->destination = AM_BROADCAST_ADDR;
      header->source = TOS_NODE_ID;
      call CXLinkPacket.setAllowRetx(txMsg, retx);   
      if (packetLength != 1){
        call CXLinkPacket.setTSLoc(txMsg, &(pl->timestamp));
      }
//      err = call Send.send(txMsg, sizeof(test_payload_t));
      err = call Send.send(txMsg, packetLength);
      printf("Send: %x %x\r\n", retx, err);
      if (err != SUCCESS){
        call Pool.put(txMsg);
        txMsg = NULL;
      }
    }
  }

  task void sendPacketNoRetx(){ 
    doSendPacket(FALSE);
  }

  task void sendPacket(){ 
    doSendPacket(TRUE);
  }

  task void sleep(){
    printf("Sleep: %x\r\n", call CXLink.sleep());
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
    printf("SD %u %x\r\n", 
      (call CXLinkPacket.getLinkHeader(msg))->sn,
      error);
    if (msg == txMsg){
      call Pool.put(txMsg);
      txMsg = NULL;
    } else{
      printf("mystery packet: %p\r\n", msg);
    }
  }

  task void handleRX(){
//    test_payload_t* pl = call Packet.getPayload(rxMsg,
//      sizeof(test_payload_t));
    printf("RX %p %u %u\r\n",
      rxMsg, 
      (call CXLinkPacket.getLinkHeader(rxMsg))->sn,
      call CXLinkPacket.payloadLength(rxMsg));
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

  event void CXLink.rxDone(){
    printf("RXD\r\n");
  }

  task void toggleStartStop(){
    if (started){
      call SplitControl.stop();
    }else {
      call SplitControl.start();
    }
  }


  event void Timer.fired(){
    call SerialControl.start();
  }

  task void nextChannel(){
    do{
      channel += 32;
    } while (channel == 0);
    printf("Next channel: %u\r\n", channel);
  }

  task void togglePacketLength(){
    packetLength = (packetLength == 1) ? call Packet.maxPayloadLength() : 1;
  }

  async event void UartStream.receivedByte(uint8_t byte){ 
     switch(byte){
       case 'q':
         WDTCTL = 0;
         break;
       case 'r':
         post receivePacket();
         break;
       case 'R':
         post receivePacketNoRetx();
         break;
       case 'C':
         post receivePacketShort();
         break;
       case 't':
         post sendPacket();
         break;
       case 'T':
         post sendPacketNoRetx();
         break;
       case 's':
         post sleep();
         break;
       case 'S':
         post toggleStartStop();
         break;
       case 'c':
         post nextChannel();
         break;
       case 'l':
         post togglePacketLength();
         break;
       case '?':
         post usage();
         break;
       case 'k':
         post killSerial();
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
