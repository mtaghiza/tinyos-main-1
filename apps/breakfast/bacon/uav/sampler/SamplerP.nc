module SamplerP{
  provides interface SplitControl;

  uses interface Resource;
  uses interface Msp430Adc12SingleChannel;
  uses interface Msp430Adc12Overflow;

  uses interface AdcConfigure<const msp430adc12_channel_config_t*>;

  provides interface Sampler;
} implementation {
  #ifndef BUFFER_SIZE
  #define BUFFER_SIZE 16
  #endif
  #ifndef NUM_BUFFERS
  #define NUM_BUFFERS 32
  #endif

  typedef struct burst_t{
    bool dirty;
    uint16_t buffer[BUFFER_SIZE];
  } burst_t;
  uint8_t lastProvided;
  burst_t bursts[NUM_BUFFERS];

//  uint16_t bufferA[BUFFER_SIZE];
//  uint16_t bufferB[BUFFER_SIZE];

//  norace uint16_t* curBuf = bufferA;
//  norace uint16_t* lastBuf = bufferB;

  norace bool stopSampling = FALSE;

  command error_t SplitControl.start(){
    return call Resource.request();
  }

  event void Resource.granted(){
    signal SplitControl.startDone(SUCCESS);
  }

  task void stopDoneTask(){
    signal SplitControl.stopDone(SUCCESS);
  }
  
  command error_t SplitControl.stop(){
    error_t err = call Resource.release();
    if (err == SUCCESS){
      post stopDoneTask();
    }
    return err;
  }
  bool outstandingReport;

  //signal up one of the used buffers
  task void reportData(){
    uint8_t i;
    for(i = 0; i < NUM_BUFFERS; i++){
      if (( i != lastProvided) && bursts[i].dirty){
        uint16_t* result = signal Sampler.burstDone(bursts[i].buffer);
        bursts[i].dirty = FALSE;
//        printf("purged: %u\r\n", i);
        if (result == NULL){
          stopSampling = TRUE;
        }
        post reportData();
        return;
      }
    }
  }

  async event uint16_t * COUNT_NOK(numSamples) Msp430Adc12SingleChannel.multipleDataReady(uint16_t *COUNT(numSamples) buffer, uint16_t numSamples) {
//    P1OUT ^= BIT1;
    if ( stopSampling){
      return NULL;
    } else {
      uint8_t i;
      //start at 1+last-provided, search for next clean buffer
      for(i = 1; i < (NUM_BUFFERS - 1) &&
        bursts[(lastProvided+i)%NUM_BUFFERS].dirty; i++){}
      lastProvided = (lastProvided +i)%NUM_BUFFERS;
//      printf("next: %u\r\n", lastProvided);
      if (bursts[lastProvided].dirty){
        printf("!O\r\n");
      }
      bursts[lastProvided].dirty = TRUE;
      post reportData();
      return bursts[lastProvided].buffer;
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
    lastProvided = 0;
    error = call Msp430Adc12SingleChannel.configureMultipleRepeat(
      call AdcConfigure.getConfiguration(),
      bursts[lastProvided].buffer, 
      BUFFER_SIZE,
      sampleInterval);

    if (error != SUCCESS){
      printf("ConfigureMultiple: %s\r\n", decodeError(error));
    }
    return error;
  }

  command error_t Sampler.startSampling(uint16_t sampleInterval){
    error_t error = configure(sampleInterval);
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

  async event error_t Msp430Adc12SingleChannel.singleDataReady(uint16_t data){
    printf("!singleDataReady\r\n");
    return SUCCESS;
  }

}
