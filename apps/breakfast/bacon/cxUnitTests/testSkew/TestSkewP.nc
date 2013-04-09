
 #include "fixedPointUtils.h"
module TestSkewP{
  uses interface Boot;
  uses interface UartStream;
  uses interface StdControl as SerialControl;
  //dummy 
  provides interface CXNetworkPacket;
} implementation {
  uint32_t remoteRate = 327680;
  uint32_t localRate = 327680;
  uint32_t framesPerCycle = 100;
  uint32_t ofs = 0;
  uint32_t ofn = 0;

  uint32_t lastTimestamp = 0;
  uint32_t lastCapture = 0;
  uint32_t lastOriginFrame = 0;


  int32_t cumulativeTpf = 0;

  #ifndef TPF_DECIMAL_PLACES 
  #define TPF_DECIMAL_PLACES 16
  #endif
  
  //alpha is also fixed point.
  #define FP_1 (1L << TPF_DECIMAL_PLACES)
  int32_t alpha = FP_1;
  
  //dummy
  message_t* schedMsg;
  cx_schedule_t sched_internal;
  cx_schedule_t* sched = &sched_internal;

  #define sfpMult(a, b) fpMult(a, b, TPF_DECIMAL_PLACES)
  #define stoFP(a) toFP(a, TPF_DECIMAL_PLACES)
  #define stoInt(a) toInt(a, TPF_DECIMAL_PLACES)
  
  void checkValues(int32_t delta, int32_t deltaFP, int32_t tpf){
    printf("delta raw %lx fp %lx tpf raw %lx over 10 : %lx -> %li 20 %lx -> %li 50: %lx -> %li 51: %lx -> %li 75: %lx -> %li 100: %lx -> %li 200: %lx -> %li  300: %lx -> %li\r\n",
      delta,
      deltaFP,
      tpf, 
      tpf*10,
      stoInt(tpf*10),
      tpf*20,
      stoInt(tpf*20),
      tpf*50,
      stoInt(tpf*50),
      tpf*51,
      stoInt(tpf*51),
      tpf*75,
      stoInt(tpf*75),
      (tpf*100),
      stoInt(tpf*100),
      (tpf*200),
      stoInt(tpf*200),
      (tpf*300),
      stoInt(tpf*300));
    printf("ctpf over 100 %li 1000 %li\r\n", 
      stoInt(cumulativeTpf*100),
      stoInt(cumulativeTpf*1000));
  }

  task void printResults(){
    printf(" Cumulative TPF: 0x%lx\r\n", 
      cumulativeTpf);
    printf("  @50 %li @51 %li @100 %li @200 %li @300 %li @400 %li @500 %li @1000 %li\r\n",
      stoInt(cumulativeTpf*50),
      stoInt(cumulativeTpf*51),
      stoInt(cumulativeTpf*100),
      stoInt(cumulativeTpf*200),
      stoInt(cumulativeTpf*300),
      stoInt(cumulativeTpf*400),
      stoInt(cumulativeTpf*500),
      stoInt(cumulativeTpf*1000));
  }

  task void updateSkew(){
    if (lastTimestamp != 0 && lastCapture != 0 && lastOriginFrame != 0){
      int32_t remoteElapsed = sched->timestamp - lastTimestamp;
      int32_t localElapsed = 
        call CXNetworkPacket.getOriginFrameStart(schedMsg) -
        lastCapture;
      int32_t framesElapsed = 
        call CXNetworkPacket.getOriginFrameNumber(schedMsg) -
        lastOriginFrame;
      //positive = we are slow = require shift forward
      int32_t delta = remoteElapsed - localElapsed;
      //this is fixed point, TPF_DECIMAL_PLACES bits after decimal
      int32_t deltaFP = (delta << TPF_DECIMAL_PLACES);

      int32_t tpf = deltaFP / framesElapsed;

      //next EWMA step
      //n.b. we let TPF = 0 initially to keep things simple. In
      //general, we should be reasonably close to this. 
//      printf("ctpf %lx scaled %lx tpf %lx scaled %lx -> ",
//        cumulativeTpf, 
//        cumulativeTpf*(FP_1-alpha),
//        tpf,
//        tpf*alpha);
      cumulativeTpf = sfpMult(cumulativeTpf, (FP_1 - alpha)) 
        + sfpMult(tpf, alpha);
//      printf(" %lx \r\n", cumulativeTpf);
//      printf("local %lu - %lu = %lu\r\n",
//        call CXNetworkPacket.getOriginFrameStart(schedMsg),
//        lastCapture,
//        localElapsed);
//      printf("remote %lu - %lu = %lu\r\n", 
//        sched->timestamp,
//        lastTimestamp,
//        remoteElapsed);
//      printf("frames %lu - %lu = %lu\r\n",
//        call CXNetworkPacket.getOriginFrameNumber(schedMsg),
//        lastOriginFrame,
//        framesElapsed);
//      checkValues(delta, deltaFP, tpf);

    }
    lastTimestamp = sched -> timestamp;
    lastCapture = call CXNetworkPacket.getOriginFrameStart(schedMsg);
    lastOriginFrame = call CXNetworkPacket.getOriginFrameNumber(schedMsg);
    post printResults();
  }


  task void usage(){
    printf("== Skew correction test ==\r\n");
    printf("--------------------------\r\n");
    printf(" q : reset\r\n");
    printf(" l : increase local speed by 1 tick per cycle\r\n");
    printf(" L : decrease local speed by 1 tick per cycle\r\n");
    printf(" r : increase remote speed by 1 tick per cycle\r\n");
    printf(" R : decrease remote speed by 1 tick per cycle\r\n");
    printf(" a : double alpha\r\n");
    printf(" A : halve alpha\r\n");
    printf(" ? : print current results + this message\r\n");
    printf(" u : update skew estimate\r\n");
    printf("..........................\r\n");
    printf(" Local rate: %lu Remote rate: %lu\r\n", 
      localRate, remoteRate);
    printf(" Alpha: %li (%lx)\r\n", stoInt(alpha), alpha);
    post printResults();
  }


  event void Boot.booted(){
    call SerialControl.start();
    printf("booted\r\n");
    post usage();
  }

  task void increaseLocal(){
    localRate ++;
  }

  task void decreaseLocal(){
    localRate --;
  }

  task void increaseRemote(){
    remoteRate ++;
  }

  task void decreaseRemote(){
    remoteRate --;
  }

  task void increaseAlpha(){
    if (alpha < FP_1){
      alpha <<= 1;
    }
  }

  task void decreaseAlpha(){
    alpha >>= 1;
  }

  task void nextMeasurement(){
    printf("add next measurement\r\n");
    ofs += localRate;
    sched->timestamp += remoteRate;
    ofn += framesPerCycle;
  }

  task void testRounding(){
    int32_t a = 4;
    int32_t a_fp = stoFP(a);
    int32_t half = stoFP(1L) >> 1;
    printf("a %li fp %lx back %li\r\n", 
      a,
      a_fp,
      stoInt(a_fp));
    printf("a.5 %li -a.5 %li\r\n",
      stoInt(a_fp+half),
      stoInt( (-1*a_fp) - half));
  }

  async event void UartStream.receivedByte(uint8_t byte){ 
    switch(byte){
      case 'q':
        WDTCTL = 0;
        break;
      case 'l':
        post increaseLocal();
        break;
      case 'L':
        post decreaseLocal();
        break;
      case 'r':
        post increaseRemote();
        break;
      case 'R':
        post decreaseRemote();
        break;
      case 'u':
        post nextMeasurement();
        post updateSkew();
        break;
      case 'a':
        post increaseAlpha();
        break;
      case 'A':
        post decreaseAlpha();
        break;
      case '?':
        post printResults();
        post usage();
        break;
      case 't':
        post testRounding();
        break;
      case '\r':
        printf("\n");
        break;
      default:
        break;
    }
    printf("%c", byte);
  }

  async event void UartStream.receiveDone( uint8_t* buf, uint16_t len,
    error_t error ){}
  async event void UartStream.sendDone( uint8_t* buf, uint16_t len,
    error_t error ){}

  command uint32_t CXNetworkPacket.getOriginFrameStart(message_t* msg){
    return ofs;
  }

  command uint32_t CXNetworkPacket.getOriginFrameNumber(message_t*
  msg){
    return ofn;
  }

  command error_t CXNetworkPacket.init(message_t* msg){}

  command void CXNetworkPacket.setTTL(message_t* msg, uint8_t ttl){}
  command uint8_t CXNetworkPacket.getTTL(message_t* msg){
    return 0;
  }

  command uint8_t CXNetworkPacket.getHops(message_t* msg){
    return 0;
  }
  
  //if TTL positive, decrement TTL and increment hop count.
  //Return true if TTL is still positive after this step.
  command bool CXNetworkPacket.readyNextHop(message_t* msg){
    return FALSE;
  }

  command uint8_t CXNetworkPacket.getRXHopCount(message_t* msg){
    return 0;
  }
  command void CXNetworkPacket.setRXHopCount(message_t* msg, 
      uint8_t rxHopCount){}
  command void CXNetworkPacket.setOriginFrameNumber(message_t* msg,
      uint32_t originFrameNumber){ }
  command void CXNetworkPacket.setOriginFrameStart(message_t* msg,
      uint32_t originFrameStart){}
}
