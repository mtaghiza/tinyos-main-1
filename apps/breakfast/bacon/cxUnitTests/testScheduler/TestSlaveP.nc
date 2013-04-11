
 #include <stdio.h>
 #include "CXLink.h"
 #include "CXNetwork.h"

module TestSlaveP{
  uses interface Boot;
  uses interface UartStream;
  
  uses interface SplitControl;
  uses interface CXRequestQueue;

  uses interface Packet;

  uses interface StdControl as SerialControl;
  
  //loopback down to scheduler: this role should be handled by an
  //AMReceiver, generally speaking
  provides interface Receive;
} implementation {
  bool started = FALSE;
  bool receivePending = FALSE;
  uint32_t reqFrame;
  int32_t reqOffset;

  message_t msg_internal;
  message_t* msg = &msg_internal;

  enum{
    PAYLOAD_LEN= 50,
  };

  typedef nx_struct test_payload {
    nx_uint8_t buffer[PAYLOAD_LEN];
    nx_uint32_t timestamp;
  } test_payload_t;


  task void usage(){
    printf("---- SLAVE Commands ----\r\n");
    printf("S : toggle start/stop\r\n");
    printf("t : transmit a packet\r\n");
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
      //enable p1.1,2,3,4 for gpio
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

  task void receiveNext(){
    error_t error = call CXRequestQueue.requestReceive(0,
      call CXRequestQueue.nextFrame(FALSE), 0,
      FALSE, 0,
      0, NULL, msg);
    if (error != SUCCESS){
      printf("reqR: %x\r\n", error);
    }
  }

  event void SplitControl.startDone(error_t error){
    printf("started %x \r\n", error);
    started = TRUE;
    post receiveNext();
  }

  event void SplitControl.stopDone(error_t error){
    printf("stopped %x\r\n", error);
    started = FALSE;
  }

  event void CXRequestQueue.frameShiftHandled(error_t error, 
      uint8_t layerCount, uint32_t atFrame, uint32_t reqFrame_){ }

  event void CXRequestQueue.receiveHandled(error_t error, 
      uint8_t layerCount, uint32_t atFrame, uint32_t reqFrame_, bool didReceive, 
      uint32_t microRef, uint32_t t32kRef, void* md, message_t* msg_){
    if (didReceive){
      uint8_t len = call Packet.payloadLength(msg_);
      printf("RX %p [%u]\r\n", msg_, len);
      msg = signal Receive.receive(msg_, 
        call Packet.getPayload(msg_, len), 
        len);
      post receiveNext();
    }else{
      if (error == SUCCESS || error == EBUSY){
        error = call CXRequestQueue.requestReceive(0,
          call CXRequestQueue.nextFrame(FALSE), 0,
          FALSE, 0,
          0,
          NULL, msg_);
        if (SUCCESS != error){
          printf("reqR: %x\r\n", error);
        }
      } else {
        printf("RX error: %x\r\n", error);
      }
    }
  }

  event void CXRequestQueue.sendHandled(error_t error, 
      uint8_t layerCount, uint32_t atFrame, uint32_t reqFrame_, uint32_t microRef,
      uint32_t t32kRef,
      void* md, message_t* msg_){
    printf("send handled: %x %lu %lu %p\r\n", error, atFrame,
      microRef, msg_);
  }

  event void CXRequestQueue.sleepHandled(error_t error,
      uint8_t layerCount, uint32_t atFrame, uint32_t reqFrame_){ }

  event void CXRequestQueue.wakeupHandled(error_t error,
      uint8_t layerCount, uint32_t atFrame, uint32_t reqFrame_){
    if (error != SUCCESS){
      printf("wakeup handled: %x @ %lu req %lu\r\n", error, atFrame,
        reqFrame_);
    }
  }

  task void transmit(){
    test_payload_t* pl = 
      (test_payload_t*)(call Packet.getPayload(msg,
        sizeof(test_payload_t)));
    error_t error;
    uint32_t nextFrame;
    {
      uint8_t i;
      for (i = 0; i < PAYLOAD_LEN; i++){
        pl->buffer[i] = i;
      }
    }
    call Packet.setPayloadLength(msg, sizeof(test_payload_t));
    nextFrame = call CXRequestQueue.nextFrame(TRUE);
    error = call CXRequestQueue.requestSend(0,
      nextFrame, 0,
      FALSE, 0, 
      &pl->timestamp,
      NULL, msg);
    printf("TX @%lu: %x\r\n", nextFrame, error);
  }

  async event void UartStream.receivedByte(uint8_t byte){ 
     switch(byte){
       case 'q':
         WDTCTL = 0;
         break;
       case 'S':
         post toggleStartStop();
         break;
       case '?':
         post usage();
         break;
       case 't':
         post transmit();
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
