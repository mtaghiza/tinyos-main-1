
 #include "Stm25p.h"

module TestP {
  uses interface UartStream;
  uses interface Boot;
  uses interface Resource;
  uses interface Stm25pSpi;
} implementation {
  uint8_t writeBuffer[254];

  event void Boot.booted() 
  {  
    uint8_t i;
    for (i = 0; i < 254; i++){
      writeBuffer[i] = 0;
    }
    printf("Test Application\n\r");
    call Resource.request();
  }

  norace uint8_t uartByte;

  uint8_t zeroLen;
  stm25p_addr_t zeroLoc;
  bool zeroLenPending= FALSE;
  bool zeroLocPending= FALSE;
  task void uartTask();
  task void writeTask();

  async event void UartStream.receivedByte( uint8_t byte ) 
  {
    uartByte = byte;

    if (uartByte == 'q')
      WDTCTL = 0;
    else
      post uartTask();  
  }

  stm25p_addr_t readAddr = 0;
  stm25p_addr_t limit = 8388608;
  uint8_t readBuf[256];

  task void readAgain(){
            call Stm25pSpi.read(readAddr, readBuf, 256);
  }
  task void uartTask()
  {
    char echo[2];
    
    uint8_t key = uartByte;

    uint16_t i;

    switch(key) {
        case 'r':
            post readAgain();
            printf("{\r\n");
            break;

        case 'z':
          zeroLoc=0;
          zeroLocPending = TRUE;
          zeroLenPending = FALSE;
          printf("zeroLoc>");
          break;

        case 'Z':
          zeroLen=0;
          zeroLenPending = TRUE;
          zeroLocPending = FALSE;
          printf("zeroLen>");
          break;

        case 'w':
          post writeTask();
          break;

        case '\r':
          printf("\r\n");
          if (zeroLenPending){
            zeroLenPending = FALSE;
          }
          if (zeroLocPending){
            zeroLocPending = FALSE;
          }
          break;
    
        default:
          if (zeroLenPending){
            zeroLen = (zeroLen*10) + key-'0';
          } else if (zeroLocPending){
            zeroLoc = (zeroLoc*10) + key-'0';
          }
          echo[0] = key;
          echo[1] = '\0';
          printf("%s", echo);
          break;
    }
  }
  
  task void writeTask(){
    printf("Zeroing out %u at %lu: %x \r\n", 
      zeroLen, zeroLoc,
      call Stm25pSpi.pageProgram(zeroLoc, writeBuffer, zeroLen));
  }

  event void Resource.granted(){
    printf("granted\r\n");
    call Stm25pSpi.powerUp();
  }

  

  async event void UartStream.sendDone( uint8_t* buf, uint16_t len, error_t error ) {}
  async event void UartStream.receiveDone( uint8_t* buf, uint16_t len, error_t error ) {}

  async event void Stm25pSpi.readDone( stm25p_addr_t addr, uint8_t* buf, 
			     stm25p_len_t len, error_t error ){
    uint16_t i;
    printf("%lu :[", readAddr);
    for (i =0 ; i < 256; i++){
      printf(" 0x%x,", buf[i]);
    }
    printf("],\r\n");
    readAddr += 256;
    if (readAddr < limit){
      post readAgain();
    }else{
      printf("}");
    }
  }
  async event void Stm25pSpi.computeCrcDone( uint16_t crc, stm25p_addr_t addr,
				   stm25p_len_t len, error_t error ){
  }
  async event void Stm25pSpi.pageProgramDone( stm25p_addr_t addr, uint8_t* buf, 
				    stm25p_len_t len, error_t error ){
    printf("PPd %x\r\n", error);
  }
  async event void Stm25pSpi.sectorEraseDone( uint8_t sector, error_t error ){
  }
  async event void Stm25pSpi.bulkEraseDone( error_t error ){
  }
}
