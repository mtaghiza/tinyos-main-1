 #include "RebootCounter.h"
module RebootCounterP{
  uses interface SettingsStorage;
  provides interface Init;
  provides interface Get<uint16_t>;
} implementation {

  uint16_t rc = 0;
  command error_t Init.init(){
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

  command uint16_t Get.get(){
    return rc;
  }
}
