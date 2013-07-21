configuration I2CComMasterC{
  provides interface I2CComMaster[uint8_t clientId];
} implementation {
  components I2CComMasterP;
  components new BaconI2CB0C() as I2CProvider;

  I2CComMasterP.I2CPacket -> I2CProvider.I2CPacket;
  I2CComMasterP.Resource -> I2CProvider.Resource;

  I2CComMaster = I2CComMasterP;
}
