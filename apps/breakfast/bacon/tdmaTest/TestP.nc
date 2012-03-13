/**
 * Test CXTDMA logic
 * 
 * @author Doug Carlson <carlson@cs.jhu.edu>
 */

#include <stdio.h>
#include "decodeError.h"
#include "Rf1a.h"
#include "message.h"

module TestP {
  uses interface Boot;
  uses interface StdControl as UartControl;
  uses interface UartStream;

  uses interface SplitControl;
  uses interface CXTDMA;

  uses interface Timer<TMilli>;
  uses interface Leds;

} implementation {
  task void printStatus(){
    printf("----\n\r");
  }

  event void Boot.booted(){
    //timing pins
    P1SEL &= ~(BIT1|BIT3|BIT4);
    P1SEL |= BIT2;
    P1DIR |= (BIT1|BIT2|BIT3|BIT4);
    P2SEL &= ~(BIT4);
    P2DIR |= (BIT4);
    //set up SFD GDO on 1.2
    atomic{
      PMAPPWD = PMAPKEY;
      PMAPCTL = PMAPRECFG;
      P1MAP2 = PM_RFGDO0;
      PMAPPWD = 0x00;
    }

    P1OUT &= ~(BIT1|BIT3|BIT4);
    P2OUT &= ~(BIT4);


    call UartControl.start();
    printf("\r\nCXTDMA test\r\n");
    printf("s: start \r\n");
    printf("S: stop \r\n");
    printf("d: toggle duty-cycled operation\r\n");
    printf("?: print status\r\n");
    printf("t: test timer\r\n");
    printf("========================\r\n");
    post printStatus();
  }

  event void SplitControl.startDone(error_t error){
    printf("%s: %s\r\n", __FUNCTION__, decodeError(error));
  }

  event void SplitControl.stopDone(error_t error){
    printf("%s: %s\r\n", __FUNCTION__, decodeError(error));
  }






  //unimplemented
  async event bool CXTDMA.isTXFrame(uint16_t frameNum){ return FALSE; }
  async event bool CXTDMA.getPacket(message_t** msg, uint8_t* len){ return FALSE; }
  async event void CXTDMA.frameStarted(uint32_t startTime){ }
  async event message_t* CXTDMA.receive(message_t* msg, uint8_t len){
    printf("!r\n\r");
    return msg;
  }

  async event void CXTDMA.sendDone(error_t error){
    printf("!sd\n\r");
  }



  task void startTask(){
    error_t error = call SplitControl.start();
    if (error != SUCCESS){
      printf("%s: %s\n\r", __FUNCTION__, decodeError(error)); 
    }
    post printStatus();
  }

  task void stopTask(){
    error_t error = call SplitControl.stop();
    if (error != SUCCESS){
      printf("%s: %s\n\r", __FUNCTION__, decodeError(error)); 
    }
    post printStatus();
  }

  event void Timer.fired(){
    call Leds.led0Toggle();
//    printf("fired\n\r");
  }

  task void testTimer(){
    if (! call Timer.isRunning()){
      call Timer.startPeriodic(1024);
    } else {
      call Timer.stop();
    }
  }

  async event void UartStream.receivedByte(uint8_t byte){
    switch(byte){
      case 'q':
        WDTCTL=0;
        break;
      case 's':
        printf("Starting\n\r");
        post startTask();
        break;
      case 'S':
        printf("Stopping\n\r");
        post stopTask();
        break;
      case '?':
        post printStatus();
        break;
      case 't':
        printf("test timer\n\r");
        post testTimer();
        break;
      case '\r':
        printf("\n\r");
        break;
     default:
        printf("%c", byte);
        break;
    }
  }

   //unused events
  async event void UartStream.receiveDone( uint8_t* buf_, uint16_t len,
    error_t error ){}
  async event void UartStream.sendDone( uint8_t* buf_, uint16_t len,
    error_t error ){}

}

/* 
 * Local Variables:
 * mode: c
 * End:
 */
