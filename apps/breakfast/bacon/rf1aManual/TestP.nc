/**
 * Stepping through low-level radio operations manually to ensure that
 * TDMA component will work as planned.
 * 
 * @author Doug Carlson <carlson@cs.jhu.edu>
 */

#include <stdio.h>
#include "decodeError.h"
#include "Rf1a.h"

module TestP {
  uses interface Boot;
  uses interface StdControl as UartControl;
  uses interface UartStream;

  uses interface HplMsp430Rf1aIf;
  uses interface Resource;
  uses interface Rf1aPhysical;
  uses interface Rf1aStatus;

} implementation {

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

    call UartControl.start();
    printf("Booted\n\r");
  }

  const char* decodeStatus(){
    switch(call Rf1aStatus.get()){
      case RF1A_S_IDLE:
        return "S_IDLE";
      case RF1A_S_RX:
        return "S_RX";
      case RF1A_S_TX:
        return "S_TX";
      case RF1A_S_FSTXON:
        return "S_FSTXON";
      case RF1A_S_CALIBRATE:
        return "S_CALIBRATE";
      case RF1A_S_FIFOMASK:
        return "S_FIFOMASK";
      case RF1A_S_SETTLING:
        return "S_SETTLING";
      case RF1A_S_RXFIFO_OVERFLOW:
        return "S_RXFIFO_OVERFLOW";
      case RF1A_S_TXFIFO_UNDERFLOW:
        return "S_TXFIFO_UNDERFLOW";
      case RF1A_S_OFFLINE:
        return "S_OFFLINE";
      default:
        return "???";
    }
  }

  task void printStatus(){
    printf("Core Status: %s\n\r", decodeStatus());
  }

  task void startTask(){
    call Resource.request();
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
      case '\r':
        printf("\n\r");
        break;
     default:
        printf("%c", byte);
        break;
    }
  }

  event void Resource.granted(){
    printf("%s: \n\r", __FUNCTION__);  
    post printStatus();
  }

  //unused events
  async event void UartStream.receiveDone( uint8_t* buf_, uint16_t len,
    error_t error ){}
  async event void UartStream.sendDone( uint8_t* buf_, uint16_t len,
    error_t error ){}

  async event void Rf1aPhysical.sendDone (int result) { }
  async event void Rf1aPhysical.receiveStarted (unsigned int length) { }
  async event void Rf1aPhysical.receiveDone (uint8_t* buffer,
                                             unsigned int count,
                                             int result) { }
  async event void Rf1aPhysical.receiveBufferFilled (uint8_t* buffer,
                                                     unsigned int count) { }
  async event void Rf1aPhysical.frameStarted () { }
  async event void Rf1aPhysical.clearChannel () { }
  async event void Rf1aPhysical.carrierSense () { }
  async event void Rf1aPhysical.released () { }

}

/* 
 * Local Variables:
 * mode: c
 * End:
 */
