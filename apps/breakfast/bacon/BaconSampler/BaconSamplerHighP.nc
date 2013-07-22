
 #include "BaconSampler.h"
module BaconSamplerHighP {
  uses interface Boot;
  uses interface LogWrite;
  uses interface Timer<TMilli>;

  uses interface StdControl as BatteryControl;
  uses interface Read<uint16_t> as BatteryRead;

  uses interface StdControl as LightControl;
  uses interface Read<uint16_t> as LightRead;

  uses interface SettingsStorage;
} implementation {
  nx_uint32_t sampleInterval = DEFAULT_SAMPLE_INTERVAL;
  bacon_sample_t sampleRec = {
    .recordType = RECORD_TYPE_BACON_SAMPLE,
    .rebootCounter = 0,
    .baseTime = 0,
    .battery = 0,
    .light = 0
  };

  event void Boot.booted(){
    call SettingsStorage.get(SS_KEY_BACON_SAMPLE_INTERVAL,
      (uint8_t*)(&sampleInterval), sizeof(sampleInterval));
    call SettingsStorage.get(SS_KEY_REBOOT_COUNTER,
      (uint8_t*)(&sampleRec.rebootCounter), 
      sizeof(sampleRec.rebootCounter));
    call Timer.startPeriodic(sampleInterval);
  }

  task void readBattery();
  task void readLight();
  task void append();

  event void Timer.fired(){
    sampleRec.baseTime = call Timer.getNow();
    sampleRec.battery = 0x0000;
    sampleRec.light = 0x0000;
    
    post readBattery();
  }

  task void readBattery(){
    error_t error = call BatteryControl.start();
    if (error == SUCCESS){
      error = call BatteryRead.read();
    }

    if (error != SUCCESS){
      call BatteryControl.stop();
      post readLight();
    }
  }

  event void BatteryRead.readDone(error_t error, uint16_t val){
    if (error == SUCCESS){
      sampleRec.battery = val;
    }
    call BatteryControl.stop();
    post readLight();
  }


  task void readLight(){
    error_t error = call LightControl.start();
    if (error == SUCCESS){
        error = call LightRead.read();
    }else{
    }
    if (error != SUCCESS){
      call LightControl.stop();
      post append();
    }
  }

  event void LightRead.readDone(error_t error, uint16_t val){
    if (error == SUCCESS){
      sampleRec.light = val;
    }
    call LightControl.stop();
    post append();
  }

  task void append(){
    call LogWrite.append(&sampleRec, sizeof(sampleRec));
  }

  event void LogWrite.appendDone(void* buf, storage_len_t len, 
    bool recordsMaybeLost, error_t error){}
  event void LogWrite.syncDone(error_t error){}
  event void LogWrite.eraseDone(error_t error){}


}
