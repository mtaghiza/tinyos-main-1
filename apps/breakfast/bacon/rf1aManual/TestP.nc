/**
 * Stepping through low-level radio operations manually to ensure that
 * TDMA component will work as planned.
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

  uses interface HplMsp430Rf1aIf;
  uses interface Resource;
  uses interface Rf1aPhysical;
  uses interface Rf1aStatus;

} implementation {
  bool nextStateRx = TRUE;

  message_t rx_msg_internal;
  message_t* rx_msg = &rx_msg_internal;

  message_t tx_msg_internal;
  message_t* tx_msg = &tx_msg_internal;

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
    printf("* Core Status: %s\n\r", decodeStatus());
    printf("* next state RX? %x\n\r", nextStateRx);
    printf("--------\n\r");
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

    call UartControl.start();
    printf("\n\rManual RF1A test\n\r");
    printf("s: start (request resource)\n\r");
    printf("r: receive (startReception/setRxBuffer)\n\r");
    printf("f: FSTXON (startTransmit)\n\r");
    printf("t: TX (completeTransmit)\n\r");
    printf("n: toggle next state RX\n\r");
    printf("========================\n\r");
    post printStatus();
  }


  task void startTask(){
    error_t error = call Resource.request();
    if (error != SUCCESS){
      printf("%s: %s\n\r", __FUNCTION__, decodeError(error)); 
    }
  }

  task void startReceiveTask(){
    error_t error;
    printf("%s: Start \n\r", __FUNCTION__);
    error = call Rf1aPhysical.setReceiveBuffer(
      (uint8_t*)(rx_msg->header),
      TOSH_DATA_LENGTH + sizeof(message_header_t),
      TRUE);
//    if (error == SUCCESS){
//      error = call Rf1aPhysical.startReception();
//    }
    printf("%s: done: %s\n\r", __FUNCTION__, decodeError(error));
    post printStatus();
  }

  task void startTransmitTask(){
    printf("%s: \n\r", __FUNCTION__);
    //TODO: startTransmit
  }

  task void completeTransmitTask(){
    printf("%s: \n\r", __FUNCTION__);
    //TODO: completeTransmit
  }

  task void toggleNextStateRXTask(){
    printf("%s: \n\r", __FUNCTION__);
    nextStateRx = !nextStateRx;
    post printStatus();
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
      case 'r':
        post startReceiveTask();
        break;
      case 'f':
        post startTransmitTask();
        break;
      case 't':
        post completeTransmitTask();
        break;
      case 'n':
        post toggleNextStateRXTask();
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
    call Rf1aPhysical.setChannel(TEST_CHANNEL);
    call HplMsp430Rf1aIf.writeSinglePATable(0x25);

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
