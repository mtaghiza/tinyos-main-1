module BaconSpiB0PortMappingP{
  provides interface Msp430PortMappingConfigure;
}implementation {
  task void reportConfig(){
    printf("pm.c\r\n");
  }
  async command error_t Msp430PortMappingConfigure.configure(){
    post reportConfig();
    return SUCCESS;
  }
  
  task void reportUnconfig(){
    printf("pm.u\r\n");
  }

  async command error_t Msp430PortMappingConfigure.unconfigure(){
    post reportUnconfig();
    return SUCCESS;
  }
}
