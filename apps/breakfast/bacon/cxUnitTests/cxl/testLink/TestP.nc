module TestP{
  uses interface Boot;
  uses interface UartStream;
  uses interface StdControl as SerialControl;

  uses interface SplitControl;
  uses interface CXLink;
  uses interface Send;
  uses interface Receive;
  uses interface Pool<message_t>;
} implementation {

  task void usage(){
    printf("USAGE\r\n");
    printf("-----\r\n");
    printf(" q: reset\r\n");
    printf(" p: receive packet\r\n");
    printf(" P: send packet\r\n");
    printf(" t: receive tone\r\n");
    printf(" T: send tone\r\n");
    printf(" s: sleep\r\n");
  }

  event void Boot.booted(){
    call SerialControl.start();
    printf("Booted\r\n");
    post usage();
    atomic{
      PMAPPWD = PMAPKEY;
      PMAPCTL = PMAPRECFG;
//      //SMCLK to 1.1
//      P1MAP1 = PM_SMCLK;
      //GDO to 2.4 (synch)
      P2MAP4 = PM_RFGDO0;
      PMAPPWD = 0x00;

      P1DIR |= BIT1;
      P1SEL &= ~BIT1;
      P1OUT &= ~BIT1;
//      P1SEL |= BIT1;
      P2DIR |= BIT4;
      P2SEL |= BIT4;
      
      //power on flash chip
      P2SEL &=~BIT1;
      P2OUT |=BIT1;
      //enable p1.2,3,4 for gpio
      P1DIR |= BIT2 | BIT3 | BIT4;
      P1SEL &= ~(BIT2 | BIT3 | BIT4);
    }
  }

  task void receivePacket(){ }
  task void sendPacket(){ }
  task void receiveTone(){ }
  task void sendTone(){ }
  task void sleep(){}

  event void SplitControl.startDone(error_t error){ }
  event void SplitControl.stopDone(error_t error){ }

  event void Send.sendDone(message_t* msg, error_t error){}

  event message_t* Receive.receive(message_t* msg, void* pl, uint8_t len){
    return msg;
  }

  event void CXLink.rxDone(){}
  event void CXLink.toneReceived(bool received){}
  event void CXLink.toneSent(){}

  async event void UartStream.receivedByte(uint8_t byte){ 
     switch(byte){
       case 'q':
         WDTCTL = 0;
         break;
       case 'p':
         post receivePacket();
         break;
       case 'P':
         post sendPacket();
         break;
       case 't':
         post receiveTone();
         break;
       case 'T':
         post sendTone();
         break;
       case 's':
         post sleep();
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
