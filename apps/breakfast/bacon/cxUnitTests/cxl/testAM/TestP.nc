module TestP{
  uses interface Boot;
  uses interface UartStream;
  uses interface StdControl as SerialControl;

  uses interface SplitControl;
  uses interface AMSend as GlobalAMSend;
  uses interface AMSend as SubNetworkAMSend;
  uses interface AMSend as RouterAMSend;
  uses interface Packet;
  uses interface CXLinkPacket;
  uses interface Receive;
  uses interface Pool<message_t>;
  
  #if CX_ROUTER == 1
  uses interface CXDownload;
  #endif
  uses interface Leds;
} implementation {

  message_t* txMsg;
  message_t* rxMsg;

  norace uint8_t txSegment;

  bool started = FALSE;
  bool continuousSend;
  task void toggleStartStop();
  
  #ifndef PAYLOAD_LEN 
  #define PAYLOAD_LEN 10
  #endif
  #define SERIAL_PAUSE_TIME 10240UL


  task void usage(){
    printf("USAGE (node %x %s)\r\n", 
      TOS_NODE_ID, 
      (CX_ROUTER==1)?"ROUTER":"LEAF");
    printf("-----\r\n");
    printf(" q: reset\r\n");
    #if CX_ROUTER == 1
    printf(" 0,1,2: download from network segment 0 (global) 1 (subnet) or 2 (router)\r\n");
    #endif
    printf(" g: transmit packet on global segment\r\n");
    printf(" s: transmit packet on subnetwork segment\r\n");
    printf(" r: transmit packet on router segment\r\n");
    printf(" T: toggle continuous transmission\r\n");
    printf(" k: kill serial (for 10 seconds)\r\n");
    printf(" S: toggle start/stop\r\n");
    printf("=====\r\n");
    printf("Pool: %u\r\n", call Pool.size());
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
  
  task void toggleContinuous(){
    continuousSend = !continuousSend;
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
      switch (txSegment){
        case NS_GLOBAL:
          err = call GlobalAMSend.send(TEST_DESTINATION, 
            txMsg, call Packet.maxPayloadLength());
          break;
        case NS_SUBNETWORK:
          err = call SubNetworkAMSend.send(TEST_DESTINATION, 
            txMsg, call Packet.maxPayloadLength());
          break;
        case NS_ROUTER:
          err = call RouterAMSend.send(TEST_DESTINATION, 
            txMsg, call Packet.maxPayloadLength());
          break;
          
      }
      printf("APP TX %x\r\n", err);
      if (err != SUCCESS){
        call Pool.put(txMsg);
        txMsg = NULL;
      }
    }
  }

  event void SplitControl.startDone(error_t error){ 
    printf("start done: %x pool: %u\r\n", error, call Pool.size());
    started = (error == SUCCESS);
  }
  event void SplitControl.stopDone(error_t error){ 
    printf("stop done: %x pool: %u\r\n", error, call Pool.size());
    started = FALSE;
  }

  void doSendDone(message_t* msg, error_t error){
    call Leds.led0Toggle();
    printf("APP TXD %x\r\n", error);
    if (msg == txMsg){
      call Pool.put(txMsg);
      txMsg = NULL;
    } else{
      printf("mystery packet: %p\r\n", msg);
    }
    if (continuousSend){
      post sendPacket();
    }
  }

  event void GlobalAMSend.sendDone(message_t* msg, error_t error){
    printf("GS.SD\r\n");
    doSendDone(msg, error);   
  }

  event void SubNetworkAMSend.sendDone(message_t* msg, error_t error){
    printf("SNS.SD\r\n");
    doSendDone(msg, error);   
  }

  event void RouterAMSend.sendDone(message_t* msg, error_t error){
    printf("RS.SD\r\n");
    doSendDone(msg, error);   
  }

  task void handleRX(){
    test_payload_t* pl = call Packet.getPayload(rxMsg,
      sizeof(test_payload_t));
    printf("APP RX %p %p\r\n", rxMsg, pl); 
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
  
  #if CX_ROUTER == 1
  norace uint8_t downloadSegment;

  task void download(){
    printf("Download %x\r\n", call CXDownload.startDownload(downloadSegment));
  }
  event void CXDownload.downloadFinished(){
    printf("Download finished\r\n");
  }
  #endif


  async event void UartStream.receivedByte(uint8_t byte){ 
     switch(byte){
       case 'q':
         WDTCTL = 0;
         break;
       case 'g':
         txSegment = NS_GLOBAL;
         post sendPacket();
         break;
       case 's':
         txSegment = NS_SUBNETWORK;
         post sendPacket();
         break;
       case 'r':
         txSegment = NS_ROUTER;
         post sendPacket();
         break;
       case 'T':
         post toggleContinuous();
         post sendPacket();
         break;
       #if CX_ROUTER == 1
       case '0':
       case '1':
       case '2':
         downloadSegment = byte-'0';
         post download();
         break;

       #endif
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
