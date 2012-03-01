/**
 * Application-level usage of CX flood primitive
 * 
 * @author Doug Carlson <carlson@cs.jhu.edu>
 */

#include "testCXFlood.h"
#include <stdio.h>
#include "decodeError.h"

module TestP {
  uses interface Boot;
  uses interface Timer<TMilli>;
  uses interface StdControl as UartControl;
  uses interface UartStream;

  uses interface AMSend;
  uses interface Receive;

  uses interface CXFloodControl;

  uses interface SplitControl;

  uses interface Rf1aPhysical;
  uses interface HplMsp430Rf1aIf;
} implementation {
  bool isSending;
  message_t msg_internal;
  message_t* _msg = &msg_internal;

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
    call SplitControl.start();
  }

  event void SplitControl.stopDone(error_t error){
  }

  event void SplitControl.startDone(error_t error){
    printf("Started\n\r");
    call Rf1aPhysical.setChannel(TEST_CHANNEL);
    call HplMsp430Rf1aIf.writeSinglePATable(POWER_SETTINGS[TEST_POWER_INDEX]);
  }

  error_t sendError;
  task void reportSend(){
    test_packet_t* pl = call AMSend.getPayload(_msg,
      sizeof(test_packet_t));
    printf("Send: %lu %s\n\r", pl->seqNum,
      decodeError(sendError));
  }

  event void Timer.fired(){
    error_t error;
    test_packet_t* pl = call AMSend.getPayload(_msg,
      sizeof(test_packet_t));
    pl -> seqNum += 2;
    error = call AMSend.send(AM_BROADCAST_ADDR, _msg, sizeof(test_packet_t));
    post reportSend();
  }

  async event void UartStream.receivedByte(uint8_t byte){
    switch(byte){
      case 'q':
        WDTCTL=0;
        break;
      case '\r':
        printf("\n\r");
        break;
      case 't':
        isSending = !isSending;
        printf("Is sending: %x\n\r", isSending);
        if (!isSending && call Timer.isRunning()){
          call Timer.stop();
        }
        if (isSending && ! call Timer.isRunning()){
          call Timer.startOneShot(1);
        }
        break;
      case 'r':
        printf("Toggle ROOT: not impl\n\r");
        break;
      default:
        printf("%c", byte);
        break;
    }
  }

  error_t sendDoneError;
  task void reportSendDone(){
    printf("sendDone: %s\n\r", decodeError(sendDoneError));
  }

  event void AMSend.sendDone(message_t* msg, error_t error){
    sendDoneError = error;
    post reportSendDone();
    call Timer.startOneShot(SEND_PERIOD);
  }

  uint32_t lastSn;
  task void reportTask(){
    printf("Received %lu\n\r", lastSn);
  }

  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
    test_packet_t* pl = (test_packet_t*)payload;
    lastSn= pl->seqNum;
    post reportTask();
    return msg;
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
