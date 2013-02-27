 #include "RebootCounter.h"
module RebootCounterP{
  uses interface SettingsStorage;
  provides interface Init;
} implementation {
  command error_t Init.init(){
    uint16_t rc = 0;
    error_t err = call SettingsStorage.get(SS_KEY_REBOOT_COUNTER,
      (uint8_t*)(&rc), sizeof(rc));
    if (err == SUCCESS || err == EINVAL){
      rc++;
      return call SettingsStorage.set(SS_KEY_REBOOT_COUNTER,
        (uint8_t*)(&rc), sizeof(rc));
    }else{
      return err;
    }
  }
}
