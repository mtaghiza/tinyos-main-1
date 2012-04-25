
module BenchmarkSDP {
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
  bool testRunning;
  uint32_t testCount = 0;
  uint8_t testNum;
  task void writeTest();
  task void readTest();

#include <stdio.h>
extern int      sprintf(char *__s, const char *__fmt, ...)
__attribute__((C));

// LFN 1: 2778 bytes


#include "diskio.c"
#include "ff.c"
//#include "option/ccsbcs.c"
//#include "ff_async.c"

  uint16_t uart_value;
  uint8_t buffer[BUF_SIZE];
  
  /***************************************************************************/
    FATFS myfs;
    FIL myfile;
    BYTE buff[16];     // File read buffer
    UINT br;           // File read count

    FATFS *fs;
    
    DWORD fre_clust, fre_sect, tot_sect;
  
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

    fs = &myfs;        
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
    
  event void SDCard.writeDone(uint32_t addr, uint8_t*buf, uint16_t count, error_t error)
  {
    call StdOut.print("SDCard write done\n\r");
  }

  event void SDCard.readDone(uint32_t addr, uint8_t*buf, uint16_t count, error_t error)
  {
    call StdOut.print("SDCard read done\n\r");
  }

  /***************************************************************************/
  /* TIMER                                                                   */
  /***************************************************************************/
  uint16_t counter;
  
  event void Timer.fired()
  {
    testRunning = FALSE;
    if (testNum){
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
      f_close(&myfile);
    }
    testNum++;
    if (testNum == 1){
      post writeTest();
    }
    if (testNum == 2){
      post readTest();
    }
  }
  
  
  task void fileTestTask()
  {
    uint16_t i;
    char filename[13];
//    char dirname[13];

    f_mount(0, &myfs);        

    for (counter = 1002; counter < 10000; counter++)
    {
      sprintf(filename, "data/%d.txt", counter);

//      call StdOut.print("mkdir: ");
//      call StdOut.printBase10uint8(f_mkdir(dirname));                  
//      call StdOut.print("\n\r");                  

      call StdOut.print("open: ");
      call StdOut.printBase10uint8(f_open(&myfile, filename, FA_WRITE | FA_OPEN_ALWAYS));                  
      call StdOut.print("\n\r");                  

      call StdOut.print("seek: ");
      call StdOut.printBase10uint8(f_lseek(&myfile, f_size(&myfile)));                  
      call StdOut.print("\n\r");                  

      call StdOut.print("printf: ");
      call StdOut.printBase10uint8(f_printf(&myfile, "%ld\n", call MilliCounter.get()));                  
      call StdOut.print("\n\r");                  

      for (i = 0; i < 1024; i++)
      {
        f_printf(&myfile, "123456789\n");
//        call StdOut.print("printf: ");
//        call StdOut.printBase10uint8(f_printf(&myfile, "%ld\n", call MilliCounter.get()));                  
//        call StdOut.print("\n\r");                  
      }

      call StdOut.print("printf: ");
      call StdOut.printBase10uint8(f_printf(&myfile, "%ld\n", call MilliCounter.get()));                  
      call StdOut.print("\n\r");                  
      
      f_close(&myfile);

      call StdOut.print(filename);
      call StdOut.print("\n\r");                  

      call Leds.led1Toggle();
    }

    f_mount(0, NULL);        

    call Leds.led0On();
  }

  async event void Msp430Counter32khz.overflow()
  {
//    call Leds.led0Toggle();
  }


  async event void MilliCounter.overflow()
  {
//    call Leds.led0Toggle();
  }

  /***************************************************************************/
  /* SERIAL                                                                  */
  /***************************************************************************/

  uint8_t tmpchar;
  uint16_t i;


  task void StdOutTask()
  {    
    char str[2];    
    atomic str[0] = tmpchar;
    
    switch(str[0]) {
      case '1':   if (call Resource.request() == FAIL)
                    call StdOut.print("Start Fail\n\r");
                  break;

      case '0':   if (call Resource.release() == SUCCESS)
                    call StdOut.print("Resource released\n\r");
                  break;

      case 'p':   call StdOut.print("print:\n\r");
                  for (i = 0; i < 512; i++)
                  {
                    call StdOut.printHex(buffer[i]);
                  }
                  call StdOut.print("\n\r");
                  break;

      case 'c':   call StdOut.print("clear:\n\r");
                  for (i = 0; i < 512; i++)
                  {
                    buffer[i] = 0;
                  }
                  break;

      case 'w':   call StdOut.print("write:\n\r");      
                  for (i = 0; i < 512; i++)
                  {
                    buffer[i] = i;
                  }

                  call StdOut.printBase10uint8(call SDCard.write(0, buffer, 512));
                  break;

      case 'r':   call StdOut.print("read:\n\r");      
                  call SDCard.read(10, buffer, 256);
                  break;

      case 't':   
                  post fileTestTask();
                  break;


      case '2':   call StdOut.print("write (2):\n\r");      
                  for (i = 0; i < 512; i++)
                  {
                    buffer[i] = 2;
                  }
                  call SDCard.write(0, buffer, 512);
                  
                  break;

      case '3':   call StdOut.print("read (2):\n\r");      
                  call SDCard.read(0, buffer, 512);
                  break;


      case 'e':   
                  call StdOut.print("erase:\n\r");      
                  call SDCard.clearSectors(0, 1);
                  break;

      case 'f':
                  f_mount(0, &myfs);        
//                  f_getfree(0, &fre_clust, &fs);

                  /* Get total sectors and free sectors */
                  tot_sect = (myfs.n_fatent - 2) * myfs.csize;
                  fre_sect = fre_clust * myfs.csize;

                  f_mount(0, NULL);        

                  /* Print free space in unit of KB (assuming 512 bytes/sector) */
                  call StdOut.printBase10uint32(tot_sect >> 1);
                  call StdOut.print(" KB total drive space\n\r");
                  call StdOut.printBase10uint32(fre_sect >> 1);
                  call StdOut.print(" KB free drive space\n\r");
                  break;

      case 'm':   
                  f_mount(0, &myfs);        
                  
                  f_open(&myfile, "1.1G", FA_READ);
                  
                  call StdOut.print("read:\n\r");      

                  f_read(&myfile, buffer, 11, &br);
                  f_close(&myfile);
                  f_mount(0, NULL);        

                  buffer[12] = '\0';
                  call StdOut.print((char*)buffer);      
                  call StdOut.print("\n\r Bytes:");      
                  call StdOut.printBase10uint16(br);
                  call StdOut.print("\n\r");      
                  break;

      case 's':   
                  f_mount(0, &myfs);        
                  
                  f_open(&myfile, "test02.txt", FA_WRITE | FA_OPEN_ALWAYS);
                  
                  f_lseek(&myfile, f_size(&myfile));
                  
                  call StdOut.print("write:\n\r");      
                  for (i = 0; i < 512; i++)
                  {
                    buffer[i] = i;
                  }

                  call StdOut.printBase10uint16(f_write(&myfile, buffer, 256, &br));
                  call StdOut.print("\n\r");      

                  call StdOut.printBase10uint16(f_close(&myfile));
                  call StdOut.print("\n\r");      

                  f_mount(0, NULL);        

//                  buffer[256] = '\0';
//                  call StdOut.print(buffer);      
//                  call StdOut.print("\n\r");      
//                  call StdOut.printBase10uint16(br);
//                  call StdOut.print("\n\r");      

//                  call StdOut.print("size: ");      
//                  call StdOut.printBase10uint32(call SDCard.readCardSize());
//                  call StdOut.print("\n\r");      
                  break;                  


      case 'q':   if (call Timer.isRunning())
                    call Timer.stop();
                  else
                    call Timer.startPeriodic(1024);
                  break;                  

      case '\r':  call StdOut.print("\n\r");
                  break;
                  
      default:    str[1] = '\0';
                  call StdOut.print(str);
                  break;
     }
  }

  task void doRead(){
    if (testRunning){
      f_read(&myfile, buffer, BUF_SIZE, &br);    
      call Leds.led0Toggle();
      if(br == BUF_SIZE){
        testCount += BUF_SIZE;
        post doRead();
      } else {
        call StdOut.print("Requested ");
        call StdOut.printBase10uint16(BUF_SIZE);
        call StdOut.print(" read ");
        call StdOut.printBase10uint16(br);
        call StdOut.print("\r\n");
      }
    }
  }

  task void readTest(){
    testCount = 0;
    f_mount(0, &myfs);        
    f_open(&myfile, TEST_FILE, FA_READ);
    f_lseek(&myfile, 0);
    call StdOut.print("READ ");
    call Timer.startOneShot(TEST_DURATION);
    testRunning = TRUE;
    post doRead();
  }
  
  task void doWrite(){
    if(testRunning){
      f_write(&myfile, buffer, BUF_SIZE, &br);
      if (br == BUF_SIZE){
        call Leds.led0Toggle();
        testCount += BUF_SIZE;
        post doWrite();
      } else {
        call StdOut.print("Requested ");
        call StdOut.printBase10uint16(BUF_SIZE);
        call StdOut.print(" wrote ");
        call StdOut.printBase10uint16(br);
        call StdOut.print("\r\n");
      }
    }
  }

  task void writeTest(){
    uint16_t bp;
    testCount = 0;
    f_mount(0, &myfs);
    f_open(&myfile, TEST_FILE, FA_WRITE|FA_OPEN_ALWAYS);
    f_lseek(&myfile,0);

    for(bp = 0; bp < BUF_SIZE; bp++){
      buffer[bp] = 'a';
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
