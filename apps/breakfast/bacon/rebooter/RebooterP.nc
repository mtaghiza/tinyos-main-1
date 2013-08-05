module RebooterP{
  uses interface Boot;
  uses interface Timer<TMilli>;
  uses interface Random;
} implementation {
  enum {
    S_SEED=0,
    S_PENDING=1,
  };
  uint8_t state = S_SEED;

  event void Boot.booted(){
    if (REBOOT_INTERVAL != 0){
      call Timer.startOneShot(REBOOT_INTERVAL/2);
    }
  }

  event void Timer.fired(){
    if (state == S_SEED){
      call Timer.startOneShot((call Random.rand32())%REBOOT_INTERVAL);
      state = S_PENDING;
    }else{
      atomic WDTCTL=0;
    }
  }
}
