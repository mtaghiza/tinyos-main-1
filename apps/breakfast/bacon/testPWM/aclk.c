//******************************************************************************
//  CC430F513x Demo - Timer_A3, Toggle P1.0, CCR0 Up Mode ISR, 32kHz ACLK
//
//  Description: Toggle P1.0 using software and the TA_1 ISR. Timer1_A is
//  configured for up mode, thus the timer overflows when TAR counts
//  to CCR0. In this example, CCR0 is loaded with 1000-1.
//  Toggle rate = 32768/(2*1000) = 16.384
//  ACLK = TACLK = 32768Hz, MCLK = SMCLK = default DCO ~1.045MHz
//
//           CC430F5137
//         ---------------
//     /|\|               |
//      | |               |
//      --|RST            |
//        |               |
//        |           P1.0|-->LED
//
//   M Morales
//   Texas Instruments Inc.
//   April 2009
//   Built with CCE Version: 3.2.2 and IAR Embedded Workbench Version: 4.11B
//******************************************************************************

#include "cc430x513x.h"

void main(void)
{
  WDTCTL = WDTPW + WDTHOLD;                 // Stop WDT

  P1DIR |= BIT1;                            // P1.0 output

  TA1CCTL0 = CCIE;                          // CCR0 interrupt enabled
  TA1CCR0 = 1000-1;
  TA1CTL = TASSEL_1 + MC_1 + TACLR;         // ACLK, upmode, clear TAR

  __bis_SR_register(LPM3_bits + GIE);       // Enter LPM3, enable interrupts
  __no_operation();                         // For debugger
}

void TIMER1_A0_ISR(void) __attribute((wakeup)) __attribute((interrupt(TIMER1_A0_VECTOR)));

// Timer A0 interrupt service routine
void TIMER1_A0_ISR(void)
{
  P1OUT ^= BIT1;                            // Toggle P1.0
}

