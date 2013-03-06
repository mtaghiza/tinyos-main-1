module DummyAlarmMicro32C {
  provides interface Alarm<TMicro, uint32_t>;
} implementation{
  
  async command void Alarm.start(uint32_t dt){}
  async command void Alarm.stop(){}
  async command bool Alarm.isRunning(){
    return FALSE;
  }
  async command void Alarm.startAt(uint32_t t0, uint32_t dt){ } 
  async command uint32_t Alarm.getNow(){ return 0;}
  async command uint32_t Alarm.getAlarm(){ return 0;}
}
