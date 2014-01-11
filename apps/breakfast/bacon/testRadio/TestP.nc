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

#include <stdio.h>
#include "radioTest.h"
module TestP{
  uses interface Boot;
  uses interface Leds;
  uses interface Timer<TMilli>;
  uses interface Timer<TMilli> as IndicatorTimer;
  uses interface Timer<TMilli> as StartTimer;

  uses interface StdControl as SerialControl;
  uses interface UartStream;

  uses interface AMSend;
//  uses interface DelayedSend;
  uses interface AMPacket;
  uses interface Packet;
  uses interface Receive;
  uses interface SplitControl;
 
  uses interface HplMsp430Rf1aIf as Rf1aIf;
  uses interface Rf1aPhysicalMetadata;
  uses interface Rf1aPhysical;
  uses interface Rf1aDumpConfig;

  uses interface CC1190;
  uses interface StdControl as AmpControl;

} implementation {
  bool needsRestart;

  bool radioBusy = FALSE;
  bool delay = FALSE;

  norace test_settings_t settings;
  uint32_t rxCounter = 0;
  //uint8_t prrBuf[PRR_BUF_LEN];
  //uint8_t prrIndex = 0;

  message_t msg_internal;
  message_t* msg = &msg_internal;

  rf1a_metadata_t metadata;

  const char* test_desc= TEST_DESC;

  void printSettings(test_settings_t* s){
    rf1a_config_t config;
    printf(" (testNum, %u)", s->testNum);
    printf(" (seqNum, %lu)", s->seqNum);
    printf(" (isSender, %x)", s->isSender);
    printf(" (power, %d)", POWER_LEVELS[s->powerIndex]);
    printf(" (hgm, %x)", s->hgm);
    printf(" (channel, %d)", s->channel);
    printf(" (report, %x)", s->report);
    printf(" (ipi, %u)", s->ipi);
    printf(" (hasFe, %x)", s->hasFe);
    printf("\r\n");
    #if RF1A_DUMP_CONFIG == 1
    call Rf1aPhysical.readConfiguration(&config);
    call Rf1aDumpConfig.display(&config);
    #endif
    printf("Current channel: %u\r\n", config.channr);
  }

  void printMinimal(test_settings_t* s){
    printf("%u %lu %d %x %d %x %u", s->testNum, s->seqNum,
      POWER_LEVELS[s->powerIndex], s->hgm, s->channel, s->hasFe,
      s->ipi);
  }

  task void printSettingsTask(){
    printf("SETTINGS");
    printSettings(&settings);
  }

  event void Boot.booted(){
    call SerialControl.start();
    printf("FLUSH\r\n");
    printf("SETUP %d %d %x %x %x %d %d %s\r\n", 
      TEST_NUM, 
      TOS_NODE_ID, 
      IS_SENDER, 
      HGM,
      HAS_FE, 
      CHANNEL,
      POWER_LEVELS[POWER_INDEX],
      TEST_DESC);
    #ifndef QUIET
    printf("Radio Test app\r\n t: toggle RX/TX mode\r\n p: increment TX power\r\n h: toggle cc1190 HGM\r\n c: increment channel\r\n i: toggle IPI (cont. v. report-able)\r\n r: toggle serial reporting\r\n q: reset\r\n");
    #endif
    settings.seqNum = 0;
    settings.isSender = IS_SENDER;
    settings.powerIndex = POWER_INDEX;
    settings.hgm = HGM;
    settings.channel = CHANNEL;
    settings.report = REPORT;
    if (USE_LONG_IPI){
      settings.ipi = LONG_IPI;
    } else{
      settings.ipi = SHORT_IPI;
    }
    settings.hasFe = HAS_FE;
    settings.testNum = TEST_NUM;
    settings.seqNum = 0;

    //memset(prrBuf, 0, PRR_BUF_LEN);

    call SplitControl.start();
    printf("Max payload length: %u\r\n", 
      call AMSend.maxPayloadLength());

    atomic{
      //map SFD to 1.2
      PMAPPWD = PMAPKEY;
      PMAPCTL = PMAPRECFG;
      P1MAP2 = PM_RFGDO0;
      PMAPPWD = 0x00;
  
      //set as output/function
      P1SEL |= BIT2;
      P1DIR |= BIT2;
  
      //disable flash chip
      P2SEL &= ~BIT1;
      P2OUT |=  BIT1;
    }
  }

  task void restartRadio(){
    call Timer.stop();
    call SplitControl.stop();
  }

  event void SplitControl.stopDone(error_t error){
    call SplitControl.start();
  }
  
  event void StartTimer.fired(){
    if (settings.isSender){
      //settings.seqNum = 0;
      memcpy(call AMSend.getPayload(msg, sizeof(test_settings_t)),
        &settings, sizeof(test_settings_t));
      call CC1190.TXMode(settings.hgm);
      call Rf1aIf.writeSinglePATable(POWER_SETTINGS[settings.powerIndex]);
      call Timer.startPeriodic(settings.ipi);
      call IndicatorTimer.stop();
    }else{
      call CC1190.RXMode(settings.hgm);
      call IndicatorTimer.startPeriodic(256);
    }
  }

  event void SplitControl.startDone(error_t error){
    needsRestart = FALSE;
    radioBusy = FALSE;
    #ifndef QUIET
    printf("Radio on\r\n");
    #endif
    call AmpControl.start();
    printf("sc.start: set channel\r\n");
    call Rf1aPhysical.setChannel(settings.channel);
    call Leds.led0Off();
    call Leds.led1Off();
    call Leds.led2Off();
    call StartTimer.startOneShot(5120);

    post printSettingsTask();
  }

  uint8_t indicatorSlot = 0;
  #define RX_LEVELS 5
  #define LEVEL_5 100UL
  #define LEVEL_4 95UL
  #define LEVEL_3 90UL
  #define LEVEL_2 50UL
  #define LEVEL_1 20UL

  #define LED_ON 2
  #define LED_OFF 0
  #define LED_BLINK 1
  
  #define THRESH_1 (LEVEL_1*100UL* MAX_RX_COUNTER)/(10000UL)
  #define THRESH_2 (LEVEL_2*100UL* MAX_RX_COUNTER)/(10000UL)
  #define THRESH_3 (LEVEL_3*100UL* MAX_RX_COUNTER)/(10000UL)
  #define THRESH_4 (LEVEL_4*100UL* MAX_RX_COUNTER)/(10000UL)
  #define THRESH_5 (LEVEL_5*100UL* MAX_RX_COUNTER)/(10000UL)

  uint32_t thresholds[RX_LEVELS+1] = {0, THRESH_1, THRESH_2, THRESH_3,
    THRESH_4, THRESH_5};

  event void IndicatorTimer.fired(){
    uint8_t level;
    uint8_t led0 = LED_OFF;
    uint8_t led1 = LED_OFF;
    uint8_t led2 = LED_OFF;
    uint8_t ledState = 0;

    call Leds.set(0);
    for (level = RX_LEVELS; level != 0 ;level--){
      if (rxCounter >= thresholds[level]){
        break;
      }
    }
    if (level > 0){
      led0 = LED_ON;
    }else{
      led0 = LED_BLINK;
    }

    if (level > 2){
      led1 = LED_ON;
    }else if (level > 1){
      led1 = LED_BLINK;
    }

    if (level > 4 ){
      led2 = LED_ON;
    }else if (level > 3){
      led2 = LED_BLINK;
    }

    //blink | on: set led
    ledState |= (led0 == LED_OFF)?(0 << 0):(1<<0);
    ledState |= (led1 == LED_OFF)?(0 << 1):(1<<1);
    ledState |= (led2 == LED_OFF)?(0 << 2):(1<<2);
    //blink & even slot: clear led
    if ((indicatorSlot % 2) == 0){
      ledState &= ~((led0 == LED_BLINK)?(1<<0):(0<<0));
      ledState &= ~((led1 == LED_BLINK)?(1<<1):(0<<1));
      ledState &= ~((led2 == LED_BLINK)?(1<<2):(0<<2));
    }
    call Leds.set(ledState);
    indicatorSlot++;
  }

  uint16_t lastSN;
//  uint32_t lastIpi;
//  #define IPI_DELAY 16
//
  event void Timer.fired(){
    if (needsRestart){
      post restartRadio();
    }else{
      if (settings.isSender){
        if (!radioBusy){
          uint8_t* pl = (uint8_t*)(call AMSend.getPayload(msg,
            sizeof(test_settings_t)));
          error_t err;
          radioBusy = TRUE;
          call Packet.clear(msg);
          {
            uint8_t i;
            for(i=0; i< call AMSend.maxPayloadLength(); i++){
              pl[i] = i;
            }
          }
          memcpy(pl, &settings, sizeof(test_settings_t));
          err = call AMSend.send(AM_BROADCAST_ADDR, msg,
            call AMSend.maxPayloadLength());
          if (err != SUCCESS){
            printf("err: %x\r\n", err);
          }else{
//            printf("%p (%u) -> %x\r\n", 
//              msg, 
//              call AMSend.maxPayloadLength(), 
//              AM_BROADCAST_ADDR);
          }
        }else{
          printf("TOO FAST-RESTART RADIO\r\n");
          call Timer.stop();
          post restartRadio();
        }
      }else{
        lastSN++;
//        printf("lost %lu (%u?)\r\n", call Timer.getNow(), lastSN);
//        call Timer.startOneShot(lastIpi + IPI_DELAY);
//  
        if (settings.report){
          #ifdef REPORT_LOST
          printf("LOST\r\n");
          #endif
        }
        if (rxCounter > 0){
          rxCounter --;
        }
      }
    }
  }

  task void sendOnce(){
    if (!radioBusy){
      error_t err;
      uint8_t* pl = (uint8_t*)(call AMSend.getPayload(msg,
        sizeof(test_settings_t)));
      radioBusy = TRUE;
      call Packet.clear(msg);
      {
        uint8_t i;
        for(i=0; i< call AMSend.maxPayloadLength(); i++){
          pl[i] = i;
        }
      }
      memcpy(pl, &settings, sizeof(test_settings_t));
      err = call AMSend.send(AM_BROADCAST_ADDR, msg,
        call AMSend.maxPayloadLength());
      printf("Send: %u \r\n", err);
//      printf("%p (%u) -> %x\r\n", 
//        msg, 
//        call AMSend.maxPayloadLength(), 
//        AM_BROADCAST_ADDR);
    }
  }

  event void AMSend.sendDone(message_t* msg_, error_t err){
    test_settings_t* pkt = call AMSend.getPayload(msg,
      sizeof(test_settings_t));
    radioBusy = FALSE;
    if (settings.report){
      //printf("TX %lu", call Timer.getNow());
      printf("TX ");
      printf("%x ", err);
      #ifdef QUIET
      printf("%d ", TOS_NODE_ID);
      printMinimal(pkt);
      printf("\r\n");
      #else
      printSettings(pkt);
      #endif

    }
    if ((pkt->ipi == LONG_IPI) || 
      ((pkt->ipi == SHORT_IPI) 
        && ((pkt->seqNum % 8) == 0))){
      call Leds.led0Toggle();
      call Leds.led1Toggle();
      call Leds.led2Toggle();
    }
    pkt->seqNum++;
    settings.seqNum++;

    if (needsRestart){
      needsRestart = FALSE;
      post restartRadio();
    } else{
      //call Timer.startOneShot(pkt->ipi);
    }
  }

  bool firstRX = TRUE;
  event message_t* Receive.receive(message_t* msg_, void* pl, uint8_t len){ 
    test_settings_t* pkt = (test_settings_t*)pl;
    uint32_t rxTime = call Timer.getNow();
    uint32_t lostAt = rxTime + ((pkt->ipi)/2);

    //1 received
    rxCounter++;
//    //subtract any intervening ones missed
//    if (! firstRX){
//      rxCounter -= (pkt->seqNum - lastSN - 1); 
//    } 
//    firstRX = FALSE;

    lastSN = pkt->seqNum;
    if (rxCounter > MAX_RX_COUNTER){
      rxCounter = MAX_RX_COUNTER;
    }

    //TODO: periodic timer component seems to be messed up: in some
    //      cases it starts immediately and fires every few ms.
//    printf("at %lu spa %lu %u from %p\r\n", rxTime, lostAt, pkt->ipi,
//      pkt);
    if (pkt->ipi != 0 && pkt->isSender){
      call Timer.startPeriodicAt(lostAt, (pkt->ipi));
    }

    call Rf1aPhysicalMetadata.store(&metadata);
    if (settings.report){
      printf("RX ");
      #ifdef QUIET
      printf("%d ", TOS_NODE_ID);
      printf("%x ", settings.hgm);
      printf("%d ", call Rf1aPhysicalMetadata.rssi(&metadata));
      printf("%d ", call Rf1aPhysicalMetadata.lqi(&metadata));
      printf("%x ", HAS_FE);
      printf("%d ", call AMPacket.source(msg_));
      printMinimal(pkt);
      printf(" %u", len);
      printf(" %x\r\n", (call Rf1aPhysicalMetadata.crcPassed(&metadata))?1:0);
      #else
      printf(" (rssi, %d)", call Rf1aPhysicalMetadata.rssi(&metadata));
      printf(" (lqi, %d)", call Rf1aPhysicalMetadata.lqi(&metadata));
      printf(" (crcPassed, %x)", (call Rf1aPhysicalMetadata.crcPassed(&metadata))?1:0);
      printSettings(pkt);
      #endif
    }else{
      printf("shhh\r\n");
    }

    return msg_;
  }

//  task void completeSend(){
//    error_t err = call DelayedSend.startSend();
//    printf("Complete Send: %x\r\n", err);
//  }

//  event void DelayedSend.sendReady(){
//    if (! delay){
//      post completeSend();
//    }else{
//      printf("Send ready: complete with 'S'\r\n");
//    }
//  }

  task void requestRestart(){
    needsRestart = TRUE;
  }

  task void toggleDelay(){
    delay = !delay;
    printf("Delay: %x\r\n", delay);
  }

  task void changeChannel(){
    printf("Changing channel to %u\r\n", settings.channel);
    call Rf1aPhysical.setChannel(settings.channel);
  }

  async event void UartStream.receivedByte(uint8_t byte){
    switch ( byte ){
      case 'd':
        post toggleDelay();
        break;
      case 's':
        post sendOnce();
        break;
//      case 'S':
//        post completeSend();
//        break;

      case '?':
        post printSettingsTask();
        break;

      case 't':
        settings.isSender = !settings.isSender;
        post printSettingsTask();
        post restartRadio();
        break;

      case 'p':
        settings.powerIndex = (settings.powerIndex+1)%NUM_POWER_LEVELS;
        post printSettingsTask();
        post requestRestart();
        break;

      case 'h':
        settings.hgm = !settings.hgm;
        post printSettingsTask();
        post requestRestart();
        break;

      case 'c':
        settings.channel = (settings.channel + CHANNEL_INCREMENT);
        post changeChannel();
//        post printSettingsTask();
//        post requestRestart();
        break;

      case 'i':
        if (settings.ipi == SHORT_IPI){
          settings.ipi = LONG_IPI;
        }else{
          settings.ipi = SHORT_IPI;
        }
        post printSettingsTask();
        post requestRestart();
        break;

      case 'r':
        settings.report = !settings.report;
        post printSettingsTask();
        post restartRadio();
        break;

      case 'q':
        atomic{
          WDTCTL = 0;
        }
        break;
      case '\r':
        printf("\r\n");
        break;
      default:
        printf("%c", byte);
        break;
    }
  }
  
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
