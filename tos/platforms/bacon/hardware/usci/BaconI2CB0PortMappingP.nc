module BaconI2CB0PortMappingP{
  provides interface Msp430PortMappingConfigure;
} implementation {

  async command error_t Msp430PortMappingConfigure.configure(){
    atomic{
      PMAPPWD = PMAPKEY;
      PMAPCTL = PMAPRECFG;
      //I2C SDA on P2.6
      //I2C SCL on P2.7
      P2MAP6 = PM_UCB0SDA;
      P2MAP7 = PM_UCB0SCL;
      PMAPPWD = 0x0;
    }
    return SUCCESS;
  }

  async command error_t Msp430PortMappingConfigure.unconfigure(){
    atomic{
      PMAPPWD = PMAPKEY;
      PMAPCTL = PMAPRECFG;
      P2MAP6 = PM_NONE;
      P2MAP7 = PM_NONE;
      PMAPPWD = 0x0;
    }
    return SUCCESS;
  }
  
}
