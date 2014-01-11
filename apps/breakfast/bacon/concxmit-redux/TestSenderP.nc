/*
 * Copyright (c) 2014 Johns Hopkins University.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
*/

//#include "printf.h"

module TestSenderP {
  uses interface Boot;
  uses {
    interface AMSend as RadioSend;
    interface SplitControl;
    interface Leds;
    interface GpioInterrupt as SendInterrupt;
    interface GeneralIO as SendPin;
    interface GpioInterrupt as EnableInterrupt;
    interface GeneralIO as EnablePin;
    interface GpioInterrupt as ResetInterrupt;
    interface GeneralIO as ResetPin;
    interface DelayedSend;
    interface HplMsp430Rf1aIf as Rf1aIf;
  }
  uses interface HplMsp430GeneralIO as HplResetPin;
  uses interface HplMsp430GeneralIO as HplEnablePin;
  uses interface Random;
  uses interface Timer<TMilli>;
} implementation {
  enum{
    S_STARTING          = 0x01,
    S_READY             = 0x02,
    S_START_NEXTCONFIG  = 0x03,
    S_RADIO_STOPPING    = 0x04,
    S_RADIO_STARTING    = 0x05,
    S_NEED_LOAD         = 0x06,
    S_LOADING           = 0x07,
    S_LOADED            = 0x08,
    S_WAITING_FOR_SEND  = 0x09,
    S_SENDING           = 0x0A,
    S_REPORTING         = 0x0B,
    S_ERROR             = 0x0C,
    S_ENABLED           = 0x0D,
  };

  message_t rmsg;

  uint8_t state = S_STARTING;
  uint16_t seqNum = 0;

  task void loadNextTask();
  
  void initPacket(message_t* msg){
    uint8_t* pl = call RadioSend.getPayload(msg, 0);
    uint8_t i;
    #if RANDOMIZE_PACKET == 1
    for (i = 0; i < call RadioSend.maxPayloadLength(); i++){
      pl[i] = call Random.rand16();
    }
    #else
    for (i = 0 ; i < call RadioSend.maxPayloadLength(); i++){
//      if (i == MARK_LOCATION + sizeof(test_packet_t)){
//        pl[i] = 0xff;
//      } else{
//        pl[i] = 0xf0;
//      }
      //Flip at MARK_LOCATION
      if ( (i +((i == MARK_LOCATION)?1:0))% 2){
        pl[i] = 0xff;
      }else{
        pl[i] = 0x00;
      }
      
  }
    #endif
  }

  event void Boot.booted(){
    printf("Booted\n\r");
    #if SENDER_1 == 1
    printf("Sender 1 (FE)\n\r");
    #else
    printf("Sender 2 (RE)\n\r");
    #endif
    //call Timer.startOneShot(128);
    call SendPin.makeInput();

    call EnablePin.makeInput();
    call HplEnablePin.setResistor(MSP430_PORT_RESISTOR_PULLDOWN);
    call EnableInterrupt.enableRisingEdge();

    call ResetPin.makeInput();
    call HplResetPin.setResistor(MSP430_PORT_RESISTOR_PULLDOWN);
    call ResetInterrupt.enableRisingEdge();
    atomic{
      //Map GDO0 to port 1.2
      // (should be IOCFG0.GDO0_CFG=0x06 in RF1A config) 
      PMAPPWD = PMAPKEY;
      PMAPCTL = PMAPRECFG;
      P1MAP2 = PM_RFGDO0;
      PMAPPWD = 0x00;
     
      P1DIR |= BIT2;
      P1SEL |= BIT2;

      //workaround to re-use SPI pins for GPIO: flash must be powered
      //but held in shutdown otherwise SPI pins get held to ground. 
      //Flash_CS# is set by default, but FLASH_EN
      //needs to be set to 1 so that VCC_FLASH gets connected to 3V
      P2DIR |= BIT1;
      P2SEL &= ~BIT1;
      P2OUT |= BIT1;
      
      //Turn on CC1190 in TX+LGM
      P3SEL &= ~(BIT4|BIT5|BIT6);
      P3DIR |= (BIT4|BIT5|BIT6);
      PJDIR |= BIT0;
      //3.5: LNA_EN
      P3OUT &= ~(BIT5);
      //3.4: PA_EN (on)
      //3.6: RFFE_OFF# (on)
      P3OUT |= BIT4|BIT6;
      //J.0: HGM (off)
      PJOUT &= ~BIT0;

    }
    call SplitControl.start();
  }

  uint8_t counter = 0;
  event void Timer.fired(){
    //call Leds.set(counter);
    counter++;
    printf("Alive: %d %x\n\r", counter, state);
    call Timer.startOneShot(2048);
  }

  task void resetInterruptTask(){
    printf("RESET\n\r");
    //trigger reset
    WDTCTL=0;
  }

  async event void ResetInterrupt.fired(){
    post resetInterruptTask();
  }

  event void SplitControl.startDone(error_t err){
    //printf("Radio on\n\r");
    atomic{
      state = S_NEED_LOAD;
      post loadNextTask();
      //Sender 1 transmits at lower power to reduce impact of capture
      //effect
      #if SENDER_1 == 1
      call Rf1aIf.writeSinglePATable(TX_POWER_1);
      #else
      call Rf1aIf.writeSinglePATable(TX_POWER_2);
      #endif
    }
  }

  task void loadNextTask(){
//    uint8_t sendLen = (call RadioSend.maxPayloadLength()) / 2;
    uint8_t sendLen = 18;
    test_packet_t* pl; 
    error_t error;
    pl = (test_packet_t*)call RadioSend.getPayload(&rmsg, sendLen);
//    printf("PL: %p \r\n", pl);
    initPacket(&rmsg);
    pl -> seqNum = seqNum;
    atomic{
      state = S_LOADING;
    }
    error = call RadioSend.send(AM_BROADCAST_ADDR, &rmsg,
      sendLen);
//    printf("RS.send %d/%d %x \r\n", sendLen, TOSH_DATA_LENGTH, error);
  }

  task void unexpectedSendReady(){
    printf("Unexpected sendReady received\n\r");
  }

  async event void DelayedSend.sendReady(){
    if (state == S_LOADING){
      state = S_LOADED;
    } else {
      post unexpectedSendReady();
    }
  }

  task void reportEnableInterrupt(){
//    printf("EI\n\r");
  }

  async event void EnableInterrupt.fired(){
    post reportEnableInterrupt();
    if (state == S_LOADED){
      //the "send" pulse is negative, so sender1 should fire at the
      //falling edge
      #ifdef SENDER1
        call SendInterrupt.enableFallingEdge();
      #else
        call SendInterrupt.enableRisingEdge();
      #endif
      state = S_ENABLED;
    }
  }

  task void reportSendInterrupt(){
//    printf("SI\n\r");
  }

  async event void SendInterrupt.fired(){
    call SendInterrupt.disable();
    call DelayedSend.completeSend();
    if (state == S_ENABLED){
      //turn off send interrupt until we're done sending/reporting this
      //one
      state = S_SENDING;
      post reportSendInterrupt();
    } else {
      state = S_ERROR;
    }
  }

  task void reportTask();
  event void RadioSend.sendDone(message_t* msg, error_t err){
    //printf("SEND DONE\n\r");
    atomic{
      if (state == S_SENDING){
        state = S_REPORTING;
      } else {
        state = S_ERROR;
      }
      post reportTask();
    }
  }

  task void reportTask(){
    uint8_t i;
    printf("TX %d ", seqNum);
    for (i=0; i< sizeof(message_header_t); i++){
      printf("%u ", rmsg.header[i]);
    }
    for (i=0; i< 20; i++){
      printf("%u ", rmsg.data[i]);
    }
    printf("\r\n");
    seqNum++;
    state = S_NEED_LOAD;
    post loadNextTask();
  }

  event void SplitControl.stopDone(error_t err){
  }

}
