//DC: replace with below for IAR
//#include "cc430x513x.h"
#include <msp430.h>

#define period 16384
#define SEND_1_OFFSET 1024

void main(void)
{
  WDTCTL = WDTPW + WDTHOLD;                 // Stop watchdog timer

  P1DIR |= BIT1;                            // P1.0 output
  P1SEL |= BIT1;

  P2DIR |= BIT4;
  P2SEL &= ~BIT4;
  P2OUT |= BIT4;
  
  PMAPPWD = 0x02D52;                        // Get write-access to port mapping regs  
  P1MAP1 = PM_TA1CCR1A;
  PMAPPWD = 0;                              // Lock port mapping registers  
  
  // Initialize LFXT1
  P5SEL |= 0x03;                            // Select XT1
  #ifndef XCAP_SETTING
  #warning "Using default XCAP_SETTING (0)"
  #define XCAP_SETTING 0
  #endif
  UCSCTL6 = (UCSCTL6 & ~(XCAP_3))|(XCAP_SETTING << 2);           // Internal load cap

  // Loop until XT1 fault flag is cleared
  do
  {
    UCSCTL7 &= ~XT1LFOFFG;                  // Clear XT1 fault flags
    P2OUT^=BIT4;
  }while (UCSCTL7&XT1LFOFFG);               // Test XT1 fault flag

  // Initialize DCO to 2.45MHz
  __bis_SR_register(SCG0);                  // Disable the FLL control loop
  UCSCTL0 = 0x0000;                         // Set lowest possible DCOx, MODx
  UCSCTL1 = DCORSEL_3;                      // Set RSELx for DCO = 4.9 MHz
  UCSCTL2 = FLLD_1 + 74;                    // Set DCO Multiplier for 2.45MHz
                                            // (N + 1) * FLLRef = Fdco
                                            // (74 + 1) * 32768 = 2.45MHz
                                            // Set FLL Div = fDCOCLK/2
  __bic_SR_register(SCG0);                  // Enable the FLL control loop

  // Worst-case settling time for the DCO when the DCO range bits have been
  // changed is n x 32 x 32 x f_MCLK / f_FLL_reference. See UCS chapter in 5xx
  // UG for optimization.
  // 32 x 32 x 2.45 MHz / 32,768 Hz = 76563 = MCLK cycles for DCO to settle
  __delay_cycles(76563);

  // Loop until XT1,XT2 & DCO fault flag is cleared
  do
  {
    UCSCTL7 &= ~(XT2OFFG + XT1LFOFFG + XT1HFOFFG + DCOFFG);
                                            // Clear XT2,XT1,DCO fault flags
    SFRIFG1 &= ~OFIFG;                      // Clear fault flags
  }while (SFRIFG1&OFIFG);                   // Test oscillator fault flag

  TA1CCTL1 = OUTMOD_7;
  TA1CTL = TASSEL__SMCLK | MC__UP;
  TA1CCR0 = 0;
  TA1CCR1 = period - 1 - SEND_1_OFFSET;
  TA1CCR0 = period - 1;
  while (1){
    P2OUT ^= BIT4;
  }
}


