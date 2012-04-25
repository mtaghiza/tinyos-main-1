module SDLoggerFileP{
  provides interface SDLogger;
  provides interface SplitControl as WriteControl;
  uses interface Resource;
  uses interface SDCard;

  uses interface Boot;

} implementation {

  #ifndef TEST_FILE 
  #define TEST_FILE "data.txt"
  #endif

//  extern int      sprintf(char *__s, const char *__fmt, ...) __attribute__((C));
  
  #include "diskio.c"
  #include "ff.c"
  FATFS myfs;
  FIL myfile;
  FATFS *fs;
  DWORD fre_clust, fre_sect, tot_sect;
  UINT br;           // File read count

  event void Boot.booted(){
  }

  command error_t SDLogger.writeRecords(uint16_t* buffer, uint8_t recordCount){
    FRESULT fr = f_write(&myfile, buffer, sizeof(uint16_t)*recordCount, &br);
//    printf("W %u fr: %x\r\n", br, fr);
    if (fr != FR_OK){
      return FAIL;
    }else{
      return SUCCESS;
    }
//    uint8_t i;
//    uint8_t bc = 1;
//    for(i = 0; i < recordCount && bc != 0; i++){
//      bc = f_printf(&myfile, "%u\n", buffer[i]);
//    }
////    if (bc != 0){
////      bc = f_printf(&myfile, "\n");
////    }
//    if (bc == 0){
//      return FAIL;
//    } else {
//      return SUCCESS;
//    }
  }

  command error_t WriteControl.start(){
    fs = &myfs;
    printf("requesting resource\r\n");
    return (call Resource.request());
  }

  event void Resource.granted(){
    FRESULT fr;
    printf("Resource granted\r\n");
    fr = f_mount(0, &myfs);
    if (fr != FR_OK){
      printf("f_mount: %x\r\n", fr);
    }else{
      fr = f_open(&myfile, TEST_FILE, FA_WRITE|FA_OPEN_ALWAYS);
      if (fr != FR_OK){
        printf("f_open: %x\r\n", fr);
      }else{
        fr = f_lseek(&myfile,0);
        if (fr != FR_OK){
          printf("f_lseek: %x\r\n", fr);
        }
      }
    }
    if (fr == FR_OK){
      signal WriteControl.startDone(SUCCESS);
    } else {
      signal WriteControl.startDone(FAIL);
    }
  }

  command error_t WriteControl.stop(){
    error_t error = call Resource.release(); 
    if (error == SUCCESS){
      f_sync(&myfile);
      f_close(&myfile);
    }
    return error;
  }

  event void SDCard.writeDone(uint32_t addr, uint8_t*buf, uint16_t count, error_t error)
  {
    printf("SDCard write done\n\r");
  }

  event void SDCard.readDone(uint32_t addr, uint8_t*buf, uint16_t count, error_t error)
  {
    printf("SDCard read done\n\r");
  }


}
