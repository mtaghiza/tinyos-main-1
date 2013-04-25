
 #include <stdio.h>
 #include "CXTransport.h"

module TestP{
  uses interface Boot;
  uses interface UartStream;
  
  uses interface SplitControl;
  uses interface AMSend;
  uses interface ScheduledAMSend;
  uses interface Receive;

  uses interface Packet;

  uses interface StdControl as SerialControl;
} implementation {
  enum{
    PAYLOAD_LEN= 49,
  };
  uint32_t sn = 0;
  typedef nx_struct test_payload {
    nx_uint8_t buffer[PAYLOAD_LEN];
    nx_uint32_t timestamp;
    nx_uint32_t sn;
  } test_payload_t;

  message_t msg_internal;
  message_t* msg = &msg_internal;

  message_t rx_msg;
  message_t* rxMsg = &rx_msg;
  test_payload_t* rx_pl;
  uint8_t rxPLL;

  bool started = FALSE;

  bool continuousTX = FALSE;



  task void usage(){
    printf("---- %s ID %x Commands ----\r\n",
      (CX_MASTER==1)?"MASTER": "SLAVE",
      TOS_NODE_ID);
    printf("S : toggle start/stop\r\n");
    printf("t : transmit a packet\r\n");
    printf("T : toggle transmit back-to-back\r\n");
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
//      if (LINK_DEBUG_FRAME_BOUNDARIES){
        P1DIR |= BIT1;
        P1SEL &= ~BIT1;
        P1OUT &= ~BIT1;
//      }else{
//        P1SEL |= BIT1;
//        P1DIR |= BIT1;
//      }
      
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


  task void transmit(){
    test_payload_t* pl = call AMSend.getPayload(msg,
      sizeof(test_payload_t));
    uint8_t i;
    error_t error;
    call Packet.clear(msg);
    for (i=0; i < PAYLOAD_LEN; i++){
      pl->buffer[i] = i;
    }
    pl -> timestamp = 0xBABEFACE;
    pl -> sn = sn++;
    error = call AMSend.send(AM_BROADCAST_ADDR, msg, sizeof(test_payload_t));
    printf("APP TX %lu %u %x\r\n", pl->sn, sizeof(test_payload_t), error);
  }

  event void AMSend.sendDone(message_t* msg_, error_t error){
    printf("SendDone %x\r\n", error);
    if (continuousTX){
      post transmit();
    }
  }

  event void ScheduledAMSend.sendDone(message_t* msg_, error_t error){
  }

  task void reportRX(){
    uint8_t i;
    printf("APP RX %lu %u: ", rx_pl->sn, rxPLL);
//    for (i = 0; i < rxPLL; i++){
//      printf("%x ", rx_pl->buffer[i]);
//    }
    printf("\r\n");
    rx_pl = NULL;
  }

  event message_t* Receive.receive(message_t* msg_, 
      void* payload, uint8_t len){
    if (rx_pl != NULL){
      printf("Still logging\r\n");
      return msg_;
    } else {
      message_t* ret = rxMsg;
      rxMsg = msg_;
      rx_pl = (test_payload_t*) payload;
      rxPLL = len;
      post reportRX();
      return ret;
    }
  }

  task void toggleTX(){
    continuousTX = !continuousTX;
    if (continuousTX){
      post transmit();
    }
  }

  async event void UartStream.receivedByte(uint8_t byte){ 
     switch(byte){
       case 'q':
         WDTCTL = 0;
         break;
       case 'S':
         post toggleStartStop();
         break;
       case 't':
         post transmit();
         break;
       case 'T':
         post toggleTX();
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

