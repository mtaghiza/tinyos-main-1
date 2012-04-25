module SamplerP{
  provides interface SplitControl;

  uses interface Resource as ADCResource;
  uses interface Msp430Adc12SingleChannel;
  uses interface Msp430Adc12Overflow;

  uses interface Resource as SDResource;
  uses interface SDCard;

  uses interface Leds;

  uses interface AdcConfigure<const msp430adc12_channel_config_t*>;

  provides interface Sampler;
} implementation {
  #ifndef BUFFER_SIZE
  #define BUFFER_SIZE 16
  #endif
  #ifndef NUM_BUFFERS
  #define NUM_BUFFERS 32
  #endif

  typedef struct burst_t {
    uint16_t buffer[BUFFER_SIZE];
  } burst_t;
  burst_t bursts[NUM_BUFFERS];
  
  //
  norace uint16_t bufferIndex = 0;

  uint8_t* flushStart;
  uint32_t flushes;
  uint32_t addr = 0;
  uint32_t endAddr = 0;
  bool markingEnd = FALSE;

  bool writing = FALSE;
  norace bool stopSampling = FALSE;

  command error_t SplitControl.start(){
    return call ADCResource.request();
  }

  event void ADCResource.granted(){
    call SDResource.request();
  }

  event void SDResource.granted(){
    signal SplitControl.startDone(SUCCESS);
  }

  task void stopDoneTask(){
    signal SplitControl.stopDone(SUCCESS);
  }
  
  command error_t SplitControl.stop(){
    error_t err = call ADCResource.release();
    if (err == SUCCESS){
      err = call SDResource.release();
      if (err == SUCCESS){
        post stopDoneTask();
      }
    }
    return err;
  }
  
  task void flushTask(){
    uint8_t* fs;
    error_t error;
    atomic{
      fs = flushStart;
    }
//    printf("flush %p\r\n", fs);
    if (writing){
      printf("!OW\r\n");
    }else{
      error = call SDCard.write(addr, fs, sizeof(burst_t)*(NUM_BUFFERS/2));
  
      if (error != SUCCESS){
        printf("SDWrite: %s\r\n", decodeError(error));
      }else{
        writing = TRUE;
      }
    }
    atomic{
      if (fs != flushStart){
        printf("!OF\r\n");
        //TODO: report overflow
      }
    }
  }

  event void SDCard.writeDone(uint32_t addr_, uint8_t*buf, uint16_t count, error_t error)
  {
    if (error == SUCCESS){
      if (!markingEnd){
        addr += count;
        writing = FALSE;
        flushes++;
        call Leds.set(flushes);
        signal Sampler.burstDone(count/sizeof(uint16_t));
      }else{
        markingEnd = TRUE;
      }
    }else{
      printf("WD Error: %s\r\n", decodeError(error));
    }
  }

  event void SDCard.readDone(uint32_t addr_, uint8_t*buf, uint16_t count, error_t error)
  {
    signal Sampler.readDone(addr_, buf, count, error);
  }
 
  #ifndef END_MARK_LEN
  #define END_MARK_LEN 8
  #endif

  task void markEnd(){
    uint8_t i, j;
    for(i = 0; i < NUM_BUFFERS; i++){
      for(j=0; j < BUFFER_SIZE; j++){
        bursts[i].buffer[j] = 0xff;
      }
    }
    markingEnd = TRUE;
    call SDCard.write(addr, (uint8_t*)bursts[0].buffer, END_MARK_LEN);
  }

  async event uint16_t * COUNT_NOK(numSamples) Msp430Adc12SingleChannel.multipleDataReady(uint16_t *COUNT(numSamples) buffer, uint16_t numSamples) {
//    P1OUT ^= BIT1;
    if ( stopSampling){
      post markEnd();
      return NULL;
    } else {
      bufferIndex = (bufferIndex+1)%NUM_BUFFERS;
      if ((bufferIndex %(NUM_BUFFERS/2))==0){
        if (bufferIndex == 0){
          flushStart = (uint8_t*)bursts[NUM_BUFFERS/2].buffer;
        }else{
          flushStart = (uint8_t*)bursts[0].buffer;
        }
//        uint8_t* flushEnd = (uint8_t*)(bursts[bufferIndex].buffer);
//        flushStart = flushEnd - (sizeof(burst_t)*(NUM_BUFFERS/2));
//        flushStart = (uint8_t*)(bursts[bufferIndex].buffer);
        post flushTask();
      }
      return bursts[bufferIndex].buffer;
    }
  }

  async event void Msp430Adc12Overflow.memOverflow(){
    printf("!memOverflow\r\n");
  }

  async event void Msp430Adc12Overflow.conversionTimeOverflow(){
    printf("!ctOverflow\r\n");
  }

  
  error_t configure(uint16_t sampleInterval){
    error_t error ;
    bufferIndex = 0;
    error = call Msp430Adc12SingleChannel.configureMultipleRepeat(
      call AdcConfigure.getConfiguration(),
      bursts[bufferIndex].buffer, 
      BUFFER_SIZE,
      sampleInterval);

    if (error != SUCCESS){
      printf("ConfigureMultiple: %s\r\n", decodeError(error));
    }
    return error;
  }


  command error_t Sampler.startSampling(uint16_t sampleInterval, 
      bool startAtZero){
    error_t error = configure(sampleInterval);
    if (startAtZero){
      addr = 0;
    }
    if (SUCCESS == error){
      error = call Msp430Adc12SingleChannel.getData();
      if (SUCCESS != error){
        printf("getData: %s\r\n", decodeError(error));
      }else{
        stopSampling = FALSE;
      }
    }
    return error;
  }

  command error_t Sampler.stopSampling(){
    if(stopSampling){
      return EALREADY;
    }else{
      endAddr = addr;
      //TODO: should write a block of nulls to the end of the SD card.
      stopSampling = TRUE;
      return SUCCESS;
    }
  }

  command uint32_t Sampler.getEnd(){
    return endAddr;
  }

  command error_t Sampler.read(uint32_t addr_, uint8_t* buf, uint16_t len){
    return call SDCard.read(addr_, buf, len);
  }

  async event error_t Msp430Adc12SingleChannel.singleDataReady(uint16_t data){
    printf("!singleDataReady\r\n");
    return SUCCESS;
  }

}
