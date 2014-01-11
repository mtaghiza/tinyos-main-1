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


generic module TestP(bool useAlarm, 
    bool useMicroTimer, 
    bool use32khzTimer, 
    bool testBusy, 
    uint32_t alarmRate){
  uses interface Boot;
  uses interface Alarm<TMicro, uint32_t>;
  uses interface Leds;
  uses interface StdControl;
  uses interface Msp430XV2ClockControl;
} implementation {
  
  task void printConfig(){
    printf("config\r\n");
    //check XT2OFF: if set to 0, then it is permanently running.
    // yes, it was set to 0.
    
    //TODO: UCS registers: SMCLKREQEN, for instance
    //TODO: TA0/TA1 registers
    //TODO: RTC registers
    //TODO: ADC12
    //TODO: USCI modules
    //TODO: watchdog
  }

  task void restartAlarm(){
    printf(".");
    atomic call Alarm.startAt(call Alarm.getAlarm(), alarmRate);
  }

  task void busyTask(){
    post busyTask();
  }

  void configurePins(){
    atomic{
  P1DIR = 0xFF; 
  P1SEL = 0x00;
  P1OUT = BIT7;
  //P1.0: OUT 0 to VCC1WB switch NC1 (not connected)
  //P1.1: OUT 0 uSD_CS#  (VCC = off), but not connected
  //P1.2: OUT - SPI_SOMI  (NC)
  //P1.3: OUT - SPI_SIMO (NC)
  //P1.4: OUT - SPI_CLK (NC)
  //P1.5: OUT - RXD (NC)
  //P1.6: OUT - TXD (NC)
  //P1.7: OUT 1 FLASH_CS# (VCC = off)

  //inputs on 0,2,5 
  P2DIR = BIT1 | BIT3 | BIT4 | BIT6 | BIT7;
  P2SEL = 0x00;
  P2OUT = 0x00; 
  //P2.0: IN  - VBAT sense (input? out to gnd?)
  //P2.1: OUT 0 FLASH_EN (0=no power to flash/sd) (connect COM1 to NC1 (p1.0, GND) )
  //P2.2: IN  - light sense (input? out to gnd?)
  //P2.3: OUT - spare (NC)
  //P2.4: IN  - CARD_DET (NC)
  //P2.5: IN  - thermistor sense (input? out to gnd?)
  //P2.6: MOD - I2C Data (NC)
  //P2.7: MOD - I2C clock (NC) 

  //0,1,2,3 active low
  P3DIR = 0xFF; 
  P3SEL = 0x00;
  P3OUT = 0x07; 
  //P3.0: OUT 1 LED0 (VCC=off)
  //P3.1: OUT 1 LED1 (VCC=off)
  //P3.2: OUT 1 LED2 (VCC=off)
  //P3.3: OUT 0 LIGHT_SENSOR_EN (GND=off)
  //P3.4: OUT 0 PA_EN (GND=off) NC on ANT
  //P3.5: OUT 0 LNA_EN (GND=off) NC on ANT
  //P3.6: OUT 0 RFFE_OFF# (GND=off) NC on ant
  //P3.7: OUT 0 1WBEN (GND = connected to P1.0)

  //just the external crystal
  P5OUT = 0x00;
  P5DIR = 0x03;
  
  //PJ.1/J.2: gnd out
  PJOUT = 0x00;
  PJDIR = 0xFF;
  //PJ.0: OUT 0 HGM (GND=off)
  //PJ.1: OUT 0 Thermistor power (GND=off)
  //PJ.2: OUT 0 VBAT_SENSE_EN (GND=off)
  //PJ.3: OUT 0 NC 

  // Turn off SVSH, SVSM
  PMMCTL0_H = 0xA5;
  SVSMHCTL = 0; 
  SVSMLCTL = 0; 
  PMMCTL0_H = 0x00; 
    }
  }

  void configureClockPins(){
    atomic{
      //map SMCLK/MCLK to pins
      PMAPPWD = PMAPKEY;
      PMAPCTL = PMAPRECFG;
      //P1.1: SMCLK
      P1MAP1 = PM_SMCLK;
      //P2.4: MCLK
      P2MAP4 = PM_MCLK;
      //P1.3: ACLK
      P1MAP3 = PM_ACLK;
      PMAPPWD = 0x00;
      
      //configure pins to function/output
      P1DIR |= BIT1;
      P1SEL |= BIT1;
      P2DIR |= BIT4;
      P2SEL |= BIT4;
      P1DIR |= BIT3;
      P1SEL |= BIT3;
      //toggle when alarm fires
      P1DIR |= BIT2;
      P1SEL &= ~BIT2;
    }
  }

  event void Boot.booted(){
//    atomic{
//      //power up flash: otherwise, it forces SPI lines to GND
//      P2SEL &= ~BIT1;
//      P2OUT |=  BIT1;
//    }
//    configureClockPins();

    call StdControl.start();
    if (useAlarm){
      post restartAlarm();
    } else if (!useMicroTimer){
      call Msp430XV2ClockControl.stopMicroTimer();
    }
    if (!use32khzTimer){
      call Msp430XV2ClockControl.stop32khzTimer();
    }
    if (testBusy){
      post busyTask();
    }
    post printConfig();
//    configurePins();
  }

  async event void Alarm.fired(){
    post restartAlarm();
  }
}
