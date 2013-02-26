module BaconSpiB0PortMappingP{
  provides interface Msp430PortMappingConfigure;
}implementation {

  async command error_t Msp430PortMappingConfigure.configure(){
    return SUCCESS;
  }

  async command error_t Msp430PortMappingConfigure.unconfigure(){
    return SUCCESS;
  }
}
