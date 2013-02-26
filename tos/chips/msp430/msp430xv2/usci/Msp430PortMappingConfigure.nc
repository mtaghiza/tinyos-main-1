interface Msp430PortMappingConfigure {
  async command error_t configure();
  async command error_t unconfigure();
}
