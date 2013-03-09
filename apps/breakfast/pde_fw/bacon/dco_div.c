//*******************************************************************************
//  CC430F513x Demo - Timer_A3, PWM TA1.1-2, Up Mode, DCO SMCLK
//
//  Description: This program generates two PWM outputs on P2.0,P2.2 using
//  Timer1_A configured for up mode. The value in CCR0, 512-1, defines the PWM
//  period and the values in CCR1 and CCR2 the PWM duty cycles. Using ~1.045MHz
//  SMCLK as TACLK, the timer period is ~500us with a 75% duty cycle on P2.0
//  and 25% on P2.2.
//  ACLK = n/a, SMCLK = MCLK = TACLK = default DCO ~1.045MHz.
//
//                CC430F5137
//            -------------------
//        /|\|                   | //         | |                   |
//         --|RST                |
//           |                   |
//           |         P2.0/TA1.1|--> CCR1 - 75% PWM
//           |         P2.2/TA1.2|--> CCR2 - 25% PWM
//
//   M Morales
//   Texas Instruments Inc.
//   April 2009
//   Built with CCE Version: 3.2.2 and IAR Embedded Workbench Version: 4.11B
//******************************************************************************

#include "cc430x513x.h"
#include "inttypes.h"

#define SR_SCG0 SCG0

void waitForStableCrystal(void){
  do{
    UCSCTL7 &= ~XT1LFOFFG; //clear XT1 fault flag
  } while(UCSCTL7 & XT1LFOFFG); //check if reset by hardware
  //reduce drive strength to minimum 
  UCSCTL6 &= ~XT1DRIVE_3;
}

void configureFLL(uint8_t clockMHz, uint8_t ocFactor){
  //FLL frequency in multiples of 32KHz
  uint8_t clock32 = (clockMHz << 5);
  uint8_t dcoTarget;
  uint16_t dcorsel;
  uint16_t divs;
  uint16_t flld;
  /* Disable FLL control */
  __bis_SR_register(SR_SCG0);

  /* Use XT1CLK as the FLL input: if it isn't valid, the module
   * will fall back to REFOCLK.  Use FLLREFDIV value 1 (selected
   * by bits 000) */
  UCSCTL3 = SELREF__XT1CLK;
  UCSCTL0 = 0x0000;                         // Set lowest possible DCOx, MODx
  
  //convert ocFactor to FLLD enum value
  switch (ocFactor){
    default:
    case 1:
      flld = FLLD__1;
      break;
    case 2:
      flld = FLLD__2;
      break;
    case 4:
      flld = FLLD__4;
      break;
    case 8:
      flld = FLLD__8;
      break;
    case 16:
      flld = FLLD__16;
      break;
    case 32:
      flld = FLLD__32;
      break;
  }
  
  //compute target DCO frequency
  dcoTarget = clockMHz * ocFactor;
  //find correct RSEL enum for target DCO frequency
  switch (dcoTarget){
    default:
    case 1:
      dcorsel = DCORSEL_1;
      break;
    case 2:
      dcorsel = DCORSEL_1;
      break;
    case 4:
      dcorsel = DCORSEL_2;
      break;
    case 8: 
      dcorsel = DCORSEL_3;
      break;
    case 16:
      dcorsel = DCORSEL_4;
      break;
    case 32:
      dcorsel = DCORSEL_5;
      break;
    case 64:
      dcorsel = DCORSEL_6;
      break;
  }

  //get divider to convert FLL -> 1 MHz SMCLK
  switch(clockMHz){
    default:
    case 1:
      divs = DIVS__1;
      break;
    case 2:
      divs = DIVS__2;
      break;
    case 4: 
      divs = DIVS__4;
      break;
    case 8: 
      divs = DIVS__8;
      break;
    case 16:
      divs = DIVS__16;
      break;
  }
  //put DCO into correct range
  UCSCTL1 = dcorsel;
  //set FLLD (overclocking enum), FLLN (target FLL frequency /32Khz)
  UCSCTL2 = flld + (clock32-1);

  __bic_SR_register(SR_SCG0);               // Enable the FLL control loop
  do {
    UCSCTL7 &= ~(XT2OFFG + XT1LFOFFG + XT1HFOFFG + DCOFFG);
    // Clear XT2,XT1,DCO fault flags
    SFRIFG1 &= ~OFIFG;                      // Clear fault flags
  } while (UCSCTL7 & DCOFFG); // Test DCO fault flag

  UCSCTL4 = SELA__XT1CLK | SELS__DCOCLKDIV | SELM__DCOCLK;
  UCSCTL5 = DIVPA__1 | DIVA__1 | divs | DIVM__1;
}

void main(void)
{
  WDTCTL = WDTPW + WDTHOLD;                 // Stop WDT

  PMAPPWD = 0x02D52;                        // Get write-access to port mapping regs  
  P2MAP4 = PM_TA1CCR1A;                     // Map TA1CCR1 output to P2.4 
  P1MAP1 = PM_SMCLK;                        // map smclk to p1.1
  P1MAP4 = PM_MCLK;
  PMAPPWD = 0;                              // Lock port mapping registers 
  
  P2DIR |= BIT4;                     // P2.4 output
  P2SEL |= BIT4;                     // P2.4 options select
  P1DIR |= BIT1;
  P1SEL |= BIT1;
  P1DIR |= BIT4;
  P1SEL |= BIT4;

  configureFLL(1, 16);

  TA1CCR0 = 0xffff;                          // PWM Period
  TA1CCTL1 = OUTMOD_7;                       // CCR1 reset/set
  TA1CCR1 = 0x8000;                          // CCR1 PWM duty cycle
  TA1CTL = TASSEL__SMCLK | ID__1 | TACLR | MC__UP ;  // SMCLK, up mode, clear TAR
//  while (1){
//    __no_operation();                        
//  }
  __bis_SR_register(LPM0_bits);             // Enter LPM0
  __no_operation();                         // For debugger
}

