
 #include "Msp430Adc12.h"
 #include "BaconSampler.h"
module BaconSamplerDummyP{
  uses interface Boot;
  uses interface LogWrite;
  uses interface Timer<TMilli>;
  uses interface SettingsStorage;
} implementation {
  bacon_sample_t sampleRec = {
    .recordType = RECORD_TYPE_BACON_SAMPLE,
    .rebootCounter = 0,
    .baseTime = 0,
    .battery = 0,
    .light = 0
  };

  event void Boot.booted(){
    nx_uint32_t sampleInterval;
    sampleInterval = DEFAULT_SAMPLE_INTERVAL;
    #if CONFIGURABLE_BACON_SAMPLE_INTERVAL == 1
    call SettingsStorage.get(SS_KEY_BACON_SAMPLE_INTERVAL,
      (uint8_t*)(&sampleInterval), sizeof(sampleInterval));
    #endif
    call SettingsStorage.get(SS_KEY_REBOOT_COUNTER,
      (uint8_t*)(&sampleRec.rebootCounter), 
      sizeof(sampleRec.rebootCounter));
    sampleRec.battery = 0xBABA;
    sampleRec.light =   0xFACE;
    call Timer.startOneShot(sampleInterval);
  }
  
  event void Timer.fired(){
    nx_uint32_t sampleInterval;
    sampleInterval = DEFAULT_SAMPLE_INTERVAL;
    sampleRec.baseTime = call Timer.getNow();
    #if CONFIGURABLE_BACON_SAMPLE_INTERVAL == 1
    call SettingsStorage.get(SS_KEY_BACON_SAMPLE_INTERVAL,
      (uint8_t*)(&sampleInterval), sizeof(sampleInterval));
    #endif
    call Timer.startOneShotAt(call Timer.gett0() + call Timer.getdt(), sampleInterval);
  }


  task void append(){
    call LogWrite.append(&sampleRec, sizeof(sampleRec));
  }

  event void LogWrite.eraseDone(error_t error){}
  event void LogWrite.syncDone(error_t error){}
  event void LogWrite.appendDone(void* buf, storage_len_t len, 
    bool recordsMaybeLost, error_t error){}
}
