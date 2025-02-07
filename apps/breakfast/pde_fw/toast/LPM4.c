//******************************************************************************
//   MSP430x24x Demo - Basic Clock, LPM3 Using WDT ISR, VLO ACLK
//
//   Description: This program operates MSP430 normally in LPM3, pulsing P1.0
//   ~ 6 second intervals. WDT ISR used to wake-up system. All I/O configured
//   as low outputs to eliminate floating inputs. Current consumption does
//   increase when LED is powered on P1.0. Demo for measuring LPM3 current.
//   ACLK = VLO/2, MCLK = SMCLK = default DCO ~1.045Mhz
//
//                MSP430F249
//             -----------------
//         /|\|              XIN|-
//          | |                 |
//          --|RST          XOUT|-
//            |                 |
//            |             P1.0|-->LED
//
//   B. Nisarga
//   Texas Instruments Inc.
//   September 2007
//   Built with CCE Version: 3.2.0 and IAR Embedded Workbench Version: 3.42A
//******************************************************************************
#include "msp430x23x.h"

volatile unsigned int i;

void main(void)
{
  //stop watchdog timer
  WDTCTL = WDTPW | WDTHOLD;
  BCSCTL3 |= LFXT1S_0;                      // ACLK src = 32khz crystal
  BCSCTL1 |= DIVA_0;                        // ACLK = VLO/1

  P1DIR = 0xFF;                             // All P1.x outputs
  P1OUT = 0;                                // All P1.x reset
  P2SEL = 0;                                // All P2.x GPIO function
  P2DIR = 0xFF;                             // All P2.x outputs
  P2OUT = 0;                                // All P2.x reset
  P4DIR = 0xFF;                             // All P4.x outputs
  P4OUT = 0;                                // All P4.x reset
  P6DIR = 0xFF;                             // All P6.x outputs
  P6OUT = 0;                                // All P6.x reset

  P3DIR = 0xFF;                             // All P3.x outputs
  P3SEL = 0x00;                             // GPIO
  P3OUT = 0x06;                             // 3.1/3.2 connected to
                                            //   external pull-ups

  P5DIR = 0xFF;                             // All P5.x outputs
  P5OUT = 0;                                // All P5.x reset
//P5SEL = 0x70;                             //clocks on 5.4, 5.5, and 5.6
                                            // 4 MCLK, 5 SMCLK, 6 ACLK
  while(1)
  {
    __bis_SR_register(LPM4_bits + GIE);     // Enter LPM4, enable interrupts
    //this should never be reached: if P6.0 toggles, we left LPM3.
    P6OUT |= 0x01;
    //P1OUT |= 0x01;                          // Set P1.0 LED on
    //for (i = 20000; i > 0; i--);            // Delay
    //P1OUT &= ~0x01;                         // Clear P1.0 LED off
  }
}
