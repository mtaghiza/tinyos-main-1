
 #include <stdio.h>
 #include "CXTransport.h"
 #include "test.h"
module TestP{
  uses interface Boot;
  uses interface UartStream;
  
  uses interface SplitControl;
  uses interface AMSend;
  uses interface Receive;

  uses interface Packet;
  uses interface AMPacket;

  uses interface StdControl as SerialControl;

  uses interface ActiveMessageAddress;

  uses interface Timer<TMilli>;
  uses interface Random;
} implementation {
  uint32_t sn = 0;
  uint8_t outstanding = 0;
  bool filling = TRUE;

  message_t msg_internal;
  message_t* msg = &msg_internal;

  message_t rx_msg;
  message_t* rxMsg = &rx_msg;
  test_payload_t* rx_pl;
  uint8_t rxPLL;

  bool started = FALSE;


  task void usage(){
    cinfo(test,"BOOTED %s ID %x \r\n",
          (CX_MASTER==1)?"MASTER": "SLAVE",
          call ActiveMessageAddress.amAddress());
  }
  
  task void toggleStartStop();
  task void transmit();

  event void Boot.booted(){
    post usage();
    post toggleStartStop();
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
      error_t error = call SplitControl.stop(); 
      cinfo(test," Stop %x \r\n", error);
    }else{
      error_t error = call SplitControl.start(); 
      cinfo(test," Start %x \r\n", error);
    }
  }

  event void Timer.fired(){
    outstanding ++;
    if (outstanding > SEND_THRESHOLD && filling){
      filling = FALSE;
      post transmit();
    }
    call Timer.startOneShot(TEST_IPI - (TEST_RANDOMIZE/2) 
      + ((call Random.rand16()) % TEST_RANDOMIZE));
  }

  event void SplitControl.startDone(error_t error){
    cinfo(test,"Started %x \r\n", error);
    started = TRUE;
    call Timer.startOneShot(TEST_STARTUP_DELAY);
  }

  event void SplitControl.stopDone(error_t error){
    cinfo(test,"Stopped %x\r\n", error);
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
    error = call AMSend.send(TEST_DESTINATION, msg, sizeof(test_payload_t));
    cinfo(test,"APP TX %lu to %x %u %x\r\n", 
      pl->sn, call AMPacket.destination(msg), 
      sizeof(test_payload_t), error);
  }

  event void AMSend.sendDone(message_t* msg_, error_t error){
    test_payload_t* pl = call AMSend.getPayload(msg_,
      sizeof(test_payload_t));
    cinfo(test,"APP TXD %lu to %x %x\r\n", 
      pl->sn, 
      call AMPacket.destination(msg_),
      error);
    if (outstanding){
      outstanding --;
      post transmit();
    }else{
      filling = TRUE;
    }
  }

  uint8_t packetRXIndex;
  
  task void printRXPacket(){
    if (packetRXIndex < sizeof(message_header_t) + TOSH_DATA_LENGTH){
      cdbg(test, "+ %u %x\r\n", 
        packetRXIndex, rxMsg->header[packetRXIndex]);
      packetRXIndex++;
      post printRXPacket();
    }else{
      rx_pl = NULL;
    }
  }

  task void reportRX(){
    //TODO: should include hop count. probably use header SN
    cinfo(test,"APP RX %lu %u\r\n", rx_pl->sn, rxPLL);
    cdbg(test, "++++\r\n");
    packetRXIndex=0;
    post printRXPacket();
  }

  event message_t* Receive.receive(message_t* msg_, 
      void* payload, uint8_t len){
    if (rx_pl != NULL){
      cwarn(test,"Still logging\r\n");
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


  async event void UartStream.receivedByte(uint8_t byte){ 
     switch(byte){
       case 'q':
         WDTCTL = 0;
         break;
       default:
         break;
     }
     cinfo(test,"%c", byte);
  }

  async event void UartStream.receiveDone( uint8_t* buf, uint16_t len,
    error_t error ){}
  async event void UartStream.sendDone( uint8_t* buf, uint16_t len,
    error_t error ){}
  async event void ActiveMessageAddress.changed(){}
}

