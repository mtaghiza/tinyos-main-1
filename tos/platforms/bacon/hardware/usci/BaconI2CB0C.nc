generic configuration BaconI2CB0C(){
  provides interface I2CPacket<TI2CBasicAddr>;
  provides interface Resource;
} implementation {
  components new Msp430UsciI2CB0C();
  I2CPacket = Msp430UsciI2CB0C;
  Resource = Msp430UsciI2CB0C;

  components BaconI2CB0PortMappingP;

  Msp430UsciI2CB0C.Msp430PortMappingConfigure -> BaconI2CB0PortMappingP;
}
