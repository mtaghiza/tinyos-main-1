configuration CC1190PinsC{
  provides interface GeneralIO as HGMPin;
  provides interface GeneralIO as LNA_ENPin;
  provides interface GeneralIO as PA_ENPin;
  provides interface GeneralIO as PowerPin;
} implementation{
  components HplMsp430GeneralIOC;
  
  components new Msp430GpioC() as HGMGpio;
  HGMGpio.HplGeneralIO -> HplMsp430GeneralIOC.PortJ0;
  HGMPin = HGMGpio;

  components new Msp430GpioC() as LNA_ENGpio;
  LNA_ENGpio.HplGeneralIO -> HplMsp430GeneralIOC.Port35;
  LNA_ENPin = LNA_ENGpio;

  components new Msp430GpioC() as PA_ENGpio;
  PA_ENGpio.HplGeneralIO -> HplMsp430GeneralIOC.Port34;
  PA_ENPin = PA_ENGpio;

  components new Msp430GpioC() as PowerGpio;
  PowerGpio.HplGeneralIO -> HplMsp430GeneralIOC.Port36;
  PowerPin = PowerGpio;
}
