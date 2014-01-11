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

#include "Rf1aPacket.h"

module TestReceiverP {
  uses interface Boot;
  uses {
    interface Receive as RadioReceive;
    interface SplitControl;
    interface Leds;
    interface Timer<TMilli>;
    interface Rf1aPhysicalMetadata;
  }
  uses interface GeneralIO as ResetPin;
  uses interface GeneralIO as EnablePin;
} implementation {
  enum{
    S_STARTING,
    S_STARTUP_WAIT,
    S_BOOT_WAIT,
    S_WAITING,
    S_INTERPACKET_WAIT,
  };

  rf1a_metadata_t metadata;
  message_t rmsg;

  uint8_t state = S_STARTING;
  uint16_t seqNum = 0;

  uint16_t sendCount;
  uint16_t PERIOD = (1<<15);

  event void Boot.booted(){
    printf("Booted\r\n");
    //P1.1: TA1 CCR1 compare output for delay trigger
    atomic{
      PMAPPWD = PMAPKEY;
      PMAPCTL = PMAPRECFG;
      P1MAP1 = PM_TA1CCR1A;
      PMAPPWD = 0x00;

      //Map GDO0 to port 1.2
      // (should be IOCFG0.GDO0_CFG=0x06 in RF1A config) 
      PMAPPWD = PMAPKEY;
      PMAPCTL = PMAPRECFG;
      P1MAP2 = PM_RFGDO0;
      PMAPPWD = 0x00;
     
      P1DIR |= BIT2;
      P1SEL |= BIT2;

    }
    P1DIR |= BIT1;
    P1SEL |= BIT1;
    P2SEL &= ~BIT4;
    P2DIR |= BIT4;
    
    //workaround to re-use SPI pins for GPIO: flash must be powered
    //but held in shutdown otherwise SPI pins get held to ground. 
    //Flash_CS# is set by default, but FLASH_EN
    //needs to be set to 1 so that VCC_FLASH gets connected to 3V
    P2DIR |= BIT1;
    P2SEL &= ~BIT1;
    P2OUT |= BIT1;

    //output mode 7: reset/set 
    TA1CCTL1 = OUTMOD_7;
    TA1CTL = TASSEL__SMCLK | MC__UP;

    //Turn on CC1190 in RX+LGM
    P3SEL &= ~(BIT4|BIT5|BIT6);
    P3DIR |= (BIT4|BIT5|BIT6);
    PJDIR |= BIT0;
    //3.4: PA_EN (off)
    P3OUT &= ~(BIT4);
    //3.5: LNA_EN (on)
    //3.6: RFFE_OFF# (on)
    P3OUT |= BIT5|BIT6;
    //J.0: HGM (off)
    PJOUT &= ~BIT0;

    //prevent senders from transmitting. we're running the compare
    //  timer too fast to reliably send a single pulse and stop it. 
    call EnablePin.makeOutput();
    call EnablePin.clr();

    //force senders to reset
    call ResetPin.clr();
    call ResetPin.makeOutput();

    call SplitControl.start();
  }

  event void SplitControl.startDone(error_t err){
    call ResetPin.set();
    state = S_STARTUP_WAIT;
    call Timer.startOneShot(STARTUP_WAIT);
  }

  task void triggerSend(){
    //tell receivers: there is a send coming momentarily.
    call EnablePin.set();
    //printf("Starting send pulses\r\n");
    state = S_WAITING;
    call Timer.startOneShot(SEND_TIMEOUT);
    atomic{
      //start PWM: negative pulse with width=send1Offset cycles of
      //  SMCLK, at _end_ of period
      //Clear SMCLK divider: run at DCOCLKDIV  (> 1 Mhz)
      UCSCTL5 &= ~(0x07 << 4);
      TA1CCR0 = 0;
      //set pulse width
      TA1CCR1 = PERIOD - SEND_1_OFFSET;
      //and off it goes
      TA1CCR0 = PERIOD - 1;
    }
    call EnablePin.clr();
  }

  event void Timer.fired(){
    switch(state){
      case S_INTERPACKET_WAIT:
      case S_STARTUP_WAIT:
        post triggerSend();
        break;
      case S_WAITING:
        //stop timer for reporting
        TA1CCR0 = 0;
        //restore SMCLK for serial usage
        UCSCTL5 |= (0x05 << 4);
        printf("TIMEOUT\r\n");
        state = S_INTERPACKET_WAIT;
        call Timer.startOneShot(INTERPACKET_WAIT);
        break;
    }
  }
  
  event void SplitControl.stopDone(error_t err){ }

  event message_t* RadioReceive.receive(message_t* msg, void* pl, uint8_t len){ 
    uint8_t i;
    test_packet_t* tpl = (test_packet_t*) pl;

    call Timer.stop();
    //stop timers for reporting
    TA1CCR0 = 0;

    call Rf1aPhysicalMetadata.store(&metadata);

    //restore SMCLK for serial usage
    UCSCTL5 |= (0x05 << 4);
    printf("RX %d %d %d %d %d ", 
      tpl->seqNum, 
      call Rf1aPhysicalMetadata.rssi(&metadata), 
      call Rf1aPhysicalMetadata.lqi(&metadata),
      call Rf1aPhysicalMetadata.crcPassed(&metadata),
      SEND_1_OFFSET);
    for (i = 0; i < sizeof(message_header_t); i++){
      printf("%u ", msg->header[i]);
    }
    for (i = 0; i < 20; i++){
      printf("%u ", msg->data[i]);
    }
    printf("\r\n");


    state = S_INTERPACKET_WAIT;
    call Timer.startOneShot(INTERPACKET_WAIT);
    return msg;
  }

}
