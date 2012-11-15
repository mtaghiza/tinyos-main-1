configuration PlatformBusPowerC{
  provides interface Init;
} implementation {
  components PlatformBusPowerP;
  components BusPowerC;

  Init = PlatformBusPowerP;

  BusPowerC.SubSplitControl -> PlatformBusPowerP;
  components HplMsp430GeneralIOC;

  components new Msp430GpioC() as EnablePin;
  EnablePin.HplGeneralIO -> HplMsp430GeneralIOC.Port37;

  components new Msp430GpioC() as I2CData;
  I2CData.HplGeneralIO -> HplMsp430GeneralIOC.Port26;

  components new Msp430GpioC() as I2CClk;
  I2CClk.HplGeneralIO -> HplMsp430GeneralIOC.Port27;

  components new Msp430GpioC() as Term1WB;
  Term1WB.HplGeneralIO -> HplMsp430GeneralIOC.Port10;

  PlatformBusPowerP.EnablePin -> EnablePin;
  PlatformBusPowerP.I2CData -> I2CData;
  PlatformBusPowerP.I2CClk -> I2CClk;
  PlatformBusPowerP.Term1WB -> Term1WB;

  components new TimerMilliC();
  PlatformBusPowerP.Timer -> TimerMilliC;
}
