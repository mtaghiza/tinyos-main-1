module FlashDumpP{
  provides interface FlashDump;
  uses interface Resource;
  uses interface Stm25pSpi;
} implementation {
  #define BPL 16
  uint8_t db[BPL];
  stm25p_addr_t de;
  stm25p_addr_t cur;
  task void readNext();

  command void FlashDump.dump(stm25p_addr_t start, stm25p_addr_t end){
    call Resource.request();
    cur = start;
    de = end;
  }

  event void Resource.granted(){
    call Stm25pSpi.powerUp();
    post readNext();
  }

  task void readNext(){
    error_t error = call Stm25pSpi.read(cur, db, BPL);
    if (SUCCESS != error){
      printf("Read err: %x\r\n", error);
    }
  }

  async event void Stm25pSpi.readDone( stm25p_addr_t addr, uint8_t* buf, stm25p_len_t len, 
		       error_t error ){
    if (error == SUCCESS){
      uint8_t i;
      printf("%lx", addr);
      for (i = 0; i < len; i++){
        printf(" %2X", buf[i]);
      }
      printf("\r\n");
      cur += len;
      if (cur < de){
        post readNext();
      }else{
        call Resource.release();
      }
    }else{
      printf("rd err: %x\r\n", error);
    }
  }

  async event void Stm25pSpi.pageProgramDone( stm25p_addr_t addr, uint8_t* buf, stm25p_len_t len, 
			error_t error ){}
  async event void Stm25pSpi.sectorEraseDone( uint8_t sector, error_t error ){}
  async event void Stm25pSpi.bulkEraseDone( error_t error){}

  async event void Stm25pSpi.computeCrcDone( uint16_t crc, stm25p_addr_t addr, stm25p_len_t len, 
			     error_t error ){}
}
