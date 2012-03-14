/**
 * Test CXTDMA logic
 * 
 * @author Doug Carlson <carlson@cs.jhu.edu>
 */

#include <stdio.h>
#include "decodeError.h"
#include "Rf1a.h"
#include "message.h"
#include "CXTDMA.h"
#include "schedule.h"

module TestP {
  uses interface Boot;
  uses interface StdControl as UartControl;
  uses interface UartStream;

  uses interface SplitControl;
  uses interface CXTDMA;

  uses interface AMPacket;
  uses interface CXPacket;
  uses interface Packet;
  uses interface Ieee154Packet;
  uses interface Rf1aPacket;

  uses interface Timer<TMilli>;
  uses interface Leds;

} implementation {
  
  message_t tx_msg_internal;
  message_t* tx_msg = &tx_msg_internal;
  norace uint8_t tx_len;

  message_t rx_msg_internal;
  message_t* rx_msg = &rx_msg_internal;
  uint8_t rx_len;
  
  //schedule info
  uint32_t lastFs;
  uint16_t framesPerSlot;
  
  uint32_t mySn = 0;
  norace bool isRoot = FALSE;

  task void printStatus(){
    printf("----\r\n");
    printf("is root: %x\r\n", isRoot);
  }

  void setupPacket(){
    cx_schedule_t* pl;
    call Rf1aPacket.configureAsData(tx_msg);
    call AMPacket.setSource(tx_msg, call AMPacket.address());
    call Ieee154Packet.setPan(tx_msg, call Ieee154Packet.localPan());
    call AMPacket.setDestination(tx_msg, AM_BROADCAST_ADDR);
    call CXPacket.setDestination(tx_msg, AM_BROADCAST_ADDR);
    call CXPacket.setCount(tx_msg, 0);
    pl = (cx_schedule_t*)call Packet.getPayload(tx_msg, sizeof(cx_schedule_t));
    pl -> rootStart = 1;
    pl -> originalFrame = 0;
    pl -> frameLen = DEFAULT_TDMA_FRAME_LEN;
    pl -> activeFrames = 8;
    pl -> inactiveFrames = 8;
    pl -> framesPerSlot = 2;
    tx_len = sizeof(cx_schedule_t) + ((uint16_t)pl - (uint16_t)tx_msg);
  }

  task void loop(){
    while(1){
      P1OUT ^= BIT4;
    }
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
      P1MAP1 = PM_MCLK;
      P1MAP3 = PM_SMCLK;
      PMAPPWD = 0x00;
      P1SEL |= (BIT1|BIT3);
    }
    post loop();
    P1OUT &= ~(BIT1|BIT3|BIT4);
    P2OUT &= ~(BIT4);
    setupPacket();

    call UartControl.start();
    printf("\r\nCXTDMA test\r\n");
    printf("s: start \r\n");
    printf("S: stop \r\n");
    printf("r: root \r\n");
    printf("f: forwarder \r\n");
    printf("?: print status\r\n");
    printf("t: test timer\r\n");
    printf("========================\r\n");
    printf("UCSCTL4 %x\r\n", UCSCTL4);
    printf("UCSCTL5 %x\r\n", UCSCTL5);
    post printStatus();
  }

  event void SplitControl.startDone(error_t error){
    printf("%s: %s\r\n", __FUNCTION__, decodeError(error));
  }

  event void SplitControl.stopDone(error_t error){
    printf("%s: %s\r\n", __FUNCTION__, decodeError(error));
  }

  async event rf1a_offmode_t CXTDMA.frameType(uint16_t frameNum){ 
    if (isRoot){
      if (frameNum == 0){
        return RF1A_OM_FSTXON;
      } else {
        return RF1A_OM_RX;
      }
    } else {
      return RF1A_OM_RX;
//      if (! isSynched){
//        return RF1A_OM_RX;
//      } else {
//        if (frameNum == TOS_NODE_ID * cxs.framesPerSlot){
//          return RF1A_OM_FSTXON;
//        } else if (! forwardNext){
//          return RF1A_OM_RX;
//        } else{
//          return RF1A_OM_FSTXON;
//        }
//      }
    }
  }

  async event bool CXTDMA.getPacket(message_t** msg, uint8_t* len){ 
    *msg = tx_msg;
    *len = tx_len;
    return TRUE; 
  }


  //unimplemented
  async event void CXTDMA.frameStarted(uint32_t startTime){ 
    lastFs = startTime;
//    printf("!fs\n\r");
  }

  task void processReceive(){
    error_t error;
    cx_schedule_t* pl = call Packet.getPayload(rx_msg, rx_len);
    framesPerSlot = pl->framesPerSlot;
    //increment number of hops
    call CXPacket.setCount(rx_msg, call CXPacket.count(rx_msg)+1);

    error = call CXTDMA.setSchedule(lastFs, 
      call CXPacket.count(rx_msg) + pl->originalFrame,
      pl->frameLen,
      DEFAULT_TDMA_FW_CHECK_LEN,
      pl->activeFrames,
      pl->inactiveFrames);

//    printf("PR SS: %s\r\n", decodeError(error));
  }

  async event message_t* CXTDMA.receive(message_t* msg, uint8_t len){
    message_t* swp = rx_msg;
    rx_msg = msg;
    rx_len = len;
    post processReceive();
    return swp;
  }

  task void setupPacketTask(){
    setupPacket();
  }

  async event void CXTDMA.sendDone(error_t error){
    if (SUCCESS != error){
      printf("!sd %x\r\n", error);
    }else{
//      printf("sd\r\n");
    }
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

  task void becomeRoot(){
    error_t error;
    uint32_t ss;
    cx_schedule_t* pl = call Packet.getPayload(tx_msg, sizeof(cx_schedule_t)); 
    isRoot = TRUE;
    setupPacket();
    ss = call CXTDMA.getNow();
    
    error = call CXTDMA.setSchedule(
      ss, 
      0,
      DEFAULT_TDMA_FRAME_LEN, 
      DEFAULT_TDMA_FW_CHECK_LEN,
      pl->activeFrames, 
      pl->inactiveFrames);
    printf("BR: setSchedule: %lu %s\r\n", ss, decodeError(error));
  }

  task void becomeForwarder(){
    error_t error;
    uint32_t ss = call CXTDMA.getNow(); 
    isRoot = FALSE;
    error = call CXTDMA.setSchedule(
      ss, 
      0,
      DEFAULT_TDMA_FRAME_LEN, 
      2*DEFAULT_TDMA_FRAME_LEN,
      1, 0);
    printf("BF: setSchedule: %lu %s\r\n", ss, decodeError(error));  
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
      case 'r':
        printf("Become Root\r\n");
        post becomeRoot();
        break;
      case 'f':
        printf("Become Forwarder\r\n");
        post becomeForwarder();
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
