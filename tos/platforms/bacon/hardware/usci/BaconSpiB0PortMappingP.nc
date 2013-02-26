module BaconSpiB0PortMappingP{
  provides interface Msp430PortMappingConfigure;
}implementation {
  async command error_t Msp430PortMappingConfigure.configure(){
    atomic{
      PMAPPWD = PMAPKEY;
      PMAPCTL = PMAPRECFG;
      //SPI CLK on P1.4
      //SPI SIMO on P1.3
      //SPI SOMI on P1.2
      P1MAP4 = PM_UCB0CLK;
      P1MAP3 = PM_UCB0SIMO;
      P1MAP2 = PM_UCB0SOMI;
      PMAPPWD = 0x0;
    }
    return SUCCESS;
  }

  async command error_t Msp430PortMappingConfigure.unconfigure(){
    atomic{
      PMAPPWD = PMAPKEY;
      PMAPCTL = PMAPRECFG;
      P1MAP4 = PM_NONE;
      P1MAP3 = PM_NONE;
      P1MAP2 = PM_NONE;
      PMAPPWD = 0x0;
    }
    return SUCCESS;
  }
}
