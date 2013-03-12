
 #include <stdio.h>
module TestP{
  uses interface Boot;
  uses interface UartStream;

  provides interface Compare<cx_request_t*>;

  uses interface Pool<cx_request_t>;
  uses interface Queue<cx_request_t*>;
} implementation {

  event void Boot.booted(){
    printf("booted\r\n");
  }

  command bool Compare.leq(cx_request_t* l, cx_request_t* r){
    return requestLeq(l, r,
      0, FALSE, 0);
  }
  
  void enqueue(request_type_t requestType){
    cx_request_t* r = call Pool.get();
    if (r != NULL){
      r->requestType = requestType;
      call Queue.enqueue(r);
    }
  }

  task void enqueueSleep(){
    printf("Enqueue sleep\r\n");
    enqueue(RT_SLEEP);
  }

  task void enqueueRX(){
    printf("Enqueue RX\r\n");
    enqueue(RT_RX);
  }

  void printRequest(cx_request_t* r){
    printf("r: %p", r);
    printf(" t %x tsb %lu fo %li rt %lu duration %lu useM %x tsm %lu msg %p\r\n",
      r->requestType,
      r->tsBase32k,
      r->frameOffset,
      r->requestedTime,
      r->duration,
      r->useTsMicro,
      r->tsMicro,
      r->msg);
  }

  task void dequeueTask(){
    if (! call Queue.empty()){
      cx_request_t* h = call Queue.dequeue();
      printRequest(h);
      call Pool.put(h);
    } else {
      printf("empty\r\n");
    }
  }

  task void compareTask(){
    uint32_t lmsValid = 1000;
    uint32_t lmsInvalid = 2000;
    uint32_t ref = 2048;

    cx_request_t l;
    cx_request_t r;
    l.requestType = RT_SLEEP;
    r.requestType = RT_SLEEP;
    l.requestedTime = 1500;
    r.requestedTime = 1500;

    l.tsBase32k = 1023;
    r.tsBase32k = 1025;
    l.frameOffset = 2;
    r.frameOffset = 2;

    //test micro off
    l.useTsMicro = TRUE;
    r.useTsMicro = FALSE;
    printf("micro off l <= r: %x\r\n", 
      requestLeq(&l, &r, 
        lmsValid, FALSE,
        ref));
    printf("micro off r <= l: %x\r\n", 
      requestLeq(&r, &l, 
        lmsValid, FALSE,
        ref));

    //test micro invalid
    printf("micro inval l <= r: %x\r\n",
      requestLeq(&l, &r, 
        lmsInvalid, TRUE,
        ref));
    printf("micro inval r <= l: %x\r\n",
      requestLeq(&r, &l, 
        lmsInvalid, TRUE,
        ref));
    
    //test valid: should be equal
    printf("val l <= r:%x\r\n",
      requestLeq(&l, &r,
        lmsValid, TRUE,
        ref));
    printf("val r <= l:%x\r\n",
      requestLeq(&r, &l,
        lmsValid, TRUE,
        ref));
  }

  async event void UartStream.receivedByte(uint8_t byte){ 
    switch(byte){
      case 'q':
        WDTCTL = 0;
        break;
      case 's':
        post enqueueSleep();
        break;
      case 'r':
        post enqueueRX();
        break;
      case 'd':
        post dequeueTask();
        break;
      case 'c':
        post compareTask();
        break;
      case '\r':
        printf("\n");
      default:
        printf("%c", byte);
    }
  }

  async event void UartStream.receiveDone( uint8_t* buf, uint16_t len,
    error_t error ){}
  async event void UartStream.sendDone( uint8_t* buf, uint16_t len,
    error_t error ){}
}
