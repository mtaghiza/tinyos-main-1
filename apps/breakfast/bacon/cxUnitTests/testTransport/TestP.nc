
 #include <stdio.h>
 #include "CXTransport.h"

module TestP{
  uses interface Boot;
  uses interface UartStream;
  
  uses interface SplitControl;
  uses interface Send;
  uses interface Receive;

  uses interface Packet;

  uses interface StdControl as SerialControl;
} implementation {

  message_t msg_internal;
  message_t* msg = &msg_internal;

  bool started = FALSE;

  enum{
    PAYLOAD_LEN= 50,
  };

  typedef nx_struct test_payload {
    nx_uint8_t buffer[PAYLOAD_LEN];
    nx_uint32_t timestamp;
  } test_payload_t;


  task void usage(){
    printf("---- Commands ----\r\n");
    printf("S : toggle start/stop\r\n");
    printf("k : kill serial (requires BSL reset/power cycle to resume)\r\n");
    printf("q : reset\r\n");
  }

  event void Boot.booted(){
    printf("Booted.\r\n");
    post usage();
    atomic{
      PMAPPWD = PMAPKEY;
      PMAPCTL = PMAPRECFG;
      //GDO to 2.4 (synch)
      P2MAP4 = PM_RFGDO0;
      P1MAP1 = PM_SMCLK;
      PMAPPWD = 0x00;
      
      P2DIR |= BIT4;
      P2SEL |= BIT4;
      if (LINK_DEBUG_FRAME_BOUNDARIES){
        P1DIR |= BIT1;
        P1SEL &= ~BIT1;
        P1OUT &= ~BIT1;
      }else{
        P1SEL |= BIT1;
        P1DIR |= BIT1;
      }
      
      //power on flash chip to open p1.1-4
      P2SEL &=~BIT1;
      P2OUT |=BIT1;

      //enable p1.2,3,4 for gpio
      P1DIR |= BIT2 | BIT3 | BIT4;
      P1SEL &= ~(BIT2 | BIT3 | BIT4);

    }
  }

  task void toggleStartStop(){
    if (started){
      printf(" Stop %x \r\n", call SplitControl.stop());
    }else{
      printf(" Start %x \r\n", call SplitControl.start());
    }
  }

  event void SplitControl.startDone(error_t error){
    printf("started %x \r\n", error);
    started = TRUE;
  }

  event void SplitControl.stopDone(error_t error){
    printf("stopped %x\r\n", error);
    started = FALSE;
  }

  task void send(){
    call Packet.setPayloadLength(msg, sizeof(test_payload_t));
    call Send.send(msg, sizeof(test_payload_t));
  }

  event void Send.sendDone(message_t* msg_, error_t error){
  }

  event message_t* Receive.receive(message_t* msg_, 
      void* payload, uint8_t len){
    printf("RX %p\r\n", msg_);
    return msg_;
  }

  async event void UartStream.receivedByte(uint8_t byte){ 
     switch(byte){
       case 'q':
         WDTCTL = 0;
         break;
       case 'S':
         post toggleStartStop();
         break;
       case 's':
         post send();
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

