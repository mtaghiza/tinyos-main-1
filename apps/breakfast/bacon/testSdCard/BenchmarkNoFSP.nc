
module BenchmarkNoFSP {
  uses {
    interface Boot;

    interface Leds;    

    interface StdControl as SerialControl;
    interface StdOut;

    interface Resource;
    interface SDCard;

    interface Timer<TMilli> as Timer;
    
    interface Counter<TMilli,uint32_t> as MilliCounter;
    interface Counter<T32khz,uint16_t> as Msp430Counter32khz;
  }  
  
} implementation {
  #ifndef BUF_SIZE
  #define BUF_SIZE 512
  #endif

  #define TEST_FILE "test.txt"
  #define TEST_DURATION 5120
  uint8_t testNum = 0;
  bool testRunning;
  uint32_t testCount = 0;
  uint32_t addr = 0;

  uint8_t tmpchar;
  uint8_t buffer[BUF_SIZE];
  
  task void doRead();
  task void doWrite();
  task void readTest();
  task void writeTest();


  /***************************************************************************/
  /* BOOT                                                                    */
  /***************************************************************************/

  event void Boot.booted() 
  {  
    call SerialControl.start();

    call StdOut.print("SD lib benchmark\r\n");
    call StdOut.print(" q: quit/restart\r\n");
    call StdOut.print(" r: read test\r\n");
    call StdOut.print(" w: write test\r\n\r\n");

    P2DIR |= BIT1;
    P2SEL &= ~BIT1;
    P2OUT |= BIT1;
    call Resource.request();
  }

  /***************************************************************************/
  /* TIMER                                                                   */
  /***************************************************************************/
  event void Resource.granted()
  {
    call Timer.startOneShot(1024);
  }
    
  event void SDCard.writeDone(uint32_t addr_, uint8_t*buf, uint16_t count, error_t error)
  {
    if (SUCCESS == error){
      if (testRunning){
        post doWrite();
      }
      testCount += count;
      addr += count;
    } else {
      call StdOut.print("WriteDone Error: ");
      call StdOut.printBase10uint8(error);
      call StdOut.print("\r\n");
    }
  }

  event void SDCard.readDone(uint32_t addr_, uint8_t*buf, uint16_t count, error_t error)
  {
//    call StdOut.print("rd\r\n");
    if (SUCCESS == error){
      if (testRunning){
        post doRead();
      }
      testCount += count;
      addr += count;
    } else {
      call StdOut.print("ReadDone Error: ");
      call StdOut.printBase10uint8(error);
      call StdOut.print("\r\n");
    }
  }

  /***************************************************************************/
  /* TIMER                                                                   */
  /***************************************************************************/
  uint16_t counter;
  
  event void Timer.fired()
  {
    testRunning = FALSE;
    if (testNum){
  //    call StdOut.printBase10uint32(call Timer.getNow());
      call StdOut.printBase10uint32(testCount);
      call StdOut.print(" B in ");
      call StdOut.printBase10uint32(TEST_DURATION);
      call StdOut.print(" bms approx. ");
      call StdOut.printBase10uint32( (testCount * 1024)/TEST_DURATION );
      call StdOut.print(" B/S (buffer size: ");
      call StdOut.printBase10uint16(BUF_SIZE);
      call StdOut.print(" FS: ");
      call StdOut.printBase10uint8(USE_FS);
      call StdOut.print(" Sync: ");
      call StdOut.printBase10uint8(SYNC_SD);
      call StdOut.print(" )\r\n");
    }
    testNum++;
    if (testNum == 1){
      post writeTest();
    }
    if (testNum == 2){
      post readTest();
    }
  }
  
  

  async event void Msp430Counter32khz.overflow()
  {
//    call Leds.led0Toggle();
  }


  async event void MilliCounter.overflow()
  {
//    call Leds.led0Toggle();
  }


  task void doRead(){
    if (testRunning){
      error_t error = call SDCard.read(addr, buffer, BUF_SIZE);
      call Leds.led0Toggle();
      if (SUCCESS != error){
        call StdOut.print("Error: ");
        call StdOut.printBase10uint8(error);
        call StdOut.print("\r\n");
      } else {
        #if SYNC_SD == 1
        signal SDCard.readDone(addr, buffer, BUF_SIZE, SUCCESS);
        #else
        //nothin, we'll get readDone in a second
        #endif
      }
    }
  }

  task void readTest(){
    addr = 0;
    testCount = 0;
    call StdOut.print("READ ");
    call Timer.startOneShot(TEST_DURATION);
    testRunning = TRUE;
    post doRead();
  }
  
  task void doWrite(){
    if(testRunning){
      error_t error = call SDCard.write(addr, buffer, BUF_SIZE);
      call Leds.led0Toggle();
      if (SUCCESS != error){
        call StdOut.print("Error: ");
        call StdOut.printBase10uint8(error);
        call StdOut.print("\r\n");
      } else {
        #if SYNC_SD == 1
        signal SDCard.writeDone(addr, buffer, BUF_SIZE, SUCCESS);
        #else
        //nothin, will get writeDone soon.
        #endif
      }
    }
  }

  task void writeTest(){
    uint16_t bp;
    testCount = 0;
    addr = 0;

    for(bp = 0; bp < BUF_SIZE; bp++){
      buffer[bp] = 0x00;
    }
    call StdOut.print("WRITE ");

    call Timer.startOneShot(TEST_DURATION);
    testRunning = TRUE;
    post doWrite();
  }

  task void performAction(){
    char str[2];
    switch(tmpchar){
      case 'q':
        WDTCTL = 0;
        break;
      case 'r':
        post readTest();
        break;
      case 'w':
        post writeTest();
        break;
      case '\r':
        call StdOut.print("\r\n");
        break;
      default: 
        str[1] = '\0';
        call StdOut.print(str);
        break;
    }
  }

  /* incoming serial data */
  async event void StdOut.get(uint8_t data) 
  {
    call Leds.led2Toggle();

    tmpchar = data;
    
    post performAction();
  }



  /***************************************************************************/
  /***************************************************************************/
  /***************************************************************************/

}
