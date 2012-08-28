//******************************************************************************
//   CC430x513x Demo - Enters LPM3 (ACLK = LFXT1)
//
//   Description: Configure ACLK = LFXT1 and enters LPM3. Measure current.
//   Note: SVS(H,L) & SVM(H,L) are disabled
//   ACLK = LFXT1 = 32kHz, MCLK = SMCLK = default DCO
//
//                 CC430x513x
//             -----------------
//        /|\ |              XIN|-
//         |  |                 | 32kHz
//         ---|RST          XOUT|-
//            |                 |
//
//   M. Morales
//   Texas Instruments Inc.
//   April 2009
//   Built with CCE Version: 3.2.2 and IAR Embedded Workbench Version: 4.11B
//******************************************************************************

#include  "cc430x513x.h"

void main(void)
{  
  WDTCTL = WDTPW+WDTHOLD;                   // Stop WDT

  P5SEL |= BIT0 + BIT1;                     // Select XT1
  UCSCTL6 |= XCAP_3;                        // Internal load cap

  // Loop until XT1,XT2 & DCO stabilizes
  do
  {
    UCSCTL7 &= ~(XT1LFOFFG + DCOFFG);
                                            // Clear LFXT1,DCO fault flags
    SFRIFG1 &= ~OFIFG;                      // Clear fault flags
  }while (SFRIFG1 & OFIFG);                   // Test oscillator fault flag

  UCSCTL6 &= ~(XT1DRIVE_3);                 // Xtal is now stable, reduce drive
                                            // strength
  // map MCLK/ACLK out to P1.1/P2.4 (to check LPM state)
//  PMAPPWD = 0x2D52;
//  P1MAP1 = PM_MCLK;
//  P2MAP4 = PM_ACLK;
//  PMAPPWD = 0;
//  P1SEL = BIT1;
//  P2SEL = BIT4;

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
  //P2.1: OUT 0 FLASH_EN (0=no power to flash/sd)
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
  while (1){
    __no_operation();
  }

  // Turn off SVSH, SVSM
  PMMCTL0_H = 0xA5;
  SVSMHCTL = 0; 
  SVSMLCTL = 0; 
  PMMCTL0_H = 0x00; 
  
  __bis_SR_register(LPM4_bits);             // Enter LPM3
  __no_operation();                         // For debugger
}
