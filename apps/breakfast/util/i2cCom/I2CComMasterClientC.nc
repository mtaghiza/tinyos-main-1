
 #include "I2CCom.h"
generic configuration I2CComMasterClientC(uint8_t clientId){
  provides interface I2CComMaster;
} implementation {
  components I2CComMasterC;
  I2CComMaster = I2CComMasterC.I2CComMaster[clientId];
  
}
