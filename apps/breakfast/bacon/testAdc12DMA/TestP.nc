
 #include <stdio.h>
 #include "decodeError.h"

module TestP{
  uses interface Boot;
  uses interface UartStream;
  uses interface StdControl as SerialControl;

  uses interface Resource;
  uses interface Msp430Adc12SingleChannel;
  uses interface Msp430Adc12Overflow;

  provides interface AdcConfigure<const msp430adc12_channel_config_t*>;
} implementation {
  #ifndef BUFFER_SIZE
  #define BUFFER_SIZE 16
  #endif

  #ifndef SAMPLE_INTERVAL
  #define SAMPLE_INTERVAL 100
  #endif

  uint16_t bufferA[BUFFER_SIZE];
  uint16_t bufferB[BUFFER_SIZE];

  norace uint16_t* curBuf = bufferA;
  uint16_t* lastBuf = bufferB;

  bool repeatSample = TRUE;

  msp430adc12_channel_config_t config = {
    //no surprises here
    inch: SUPPLY_VOLTAGE_HALF_CHANNEL,
    sref: REFERENCE_VREFplus_AVss,
    ref2_5v: REFVOLT_LEVEL_2_5,
    //these determine t_sample, and should be based on SMCLK frequency
    //  and impedance of the input
    adc12ssel: SHT_SOURCE_SMCLK,
    adc12div: SHT_CLOCK_DIV_1,
    sht: SAMPLE_HOLD_4_CYCLES,
    //these define a "jiffy": if we use the same clock for SAMPCON and
    //  SHI, then the fastest sampling rate will be X + 13
    //  (SAMPLE_HOLD_X_CYCLES + 13 for conversion)
    sampcon_ssel: SAMPCON_SOURCE_SMCLK,
    sampcon_id: SAMPCON_CLOCK_DIV_1,
  };

  task void printWelcome(){
    printf("ADC12 + DMA Test\r\n");
    printf(" r: toggle repeated-sampling (currently: %x)\r\n",
      repeatSample);
    printf(" s: start sampling\r\n");
    printf(" q: reset\r\n");
  }

  event void Boot.booted(){
    P1SEL &= ~BIT1;
    P1OUT &= ~BIT1;
    P1DIR |= BIT1;

    call SerialControl.start();
    call Resource.request();
  }

  task void reportData(){
//    printf("sampling done\r\n");  
    //TODO: use UartStream, flash, or SDCard to record the data.
//    printf("%u\r\n", lastBuf[0]);
  }

  async event uint16_t * COUNT_NOK(numSamples) Msp430Adc12SingleChannel.multipleDataReady(uint16_t *COUNT(numSamples) buffer, uint16_t numSamples) {
    uint16_t* swp;
    P1OUT ^= BIT1;
    swp = lastBuf;
    if (curBuf != buffer){
      printf("!Buffer mismatch\r\n");
      return NULL;
    }
    lastBuf = curBuf;
    curBuf = swp;
    post reportData();
    if (repeatSample){
      return curBuf;
    }else{
      return NULL;
    }
  }

  async event void Msp430Adc12Overflow.memOverflow(){
    printf("!memOverflow\r\n");
  }

  async event void Msp430Adc12Overflow.conversionTimeOverflow(){
    printf("!ctOverflow\r\n");
  }

  
  task void configure(){
    error_t error = call Msp430Adc12SingleChannel.configureMultipleRepeat(
      call AdcConfigure.getConfiguration(), curBuf, BUFFER_SIZE,
      SAMPLE_INTERVAL);

    if (error != SUCCESS){
      printf("ConfigureMultiple: %s\r\n", decodeError(error));
    }
  }

  event void Resource.granted(){
    post printWelcome();
    post configure();
  }

  task void sample(){
    error_t error = call Msp430Adc12SingleChannel.getData();
    if (SUCCESS != error){
      printf("getData: %s\r\n", decodeError(error));
    }else{
      printf("Start\r\n");
    }
  }

  async event void UartStream.receivedByte(uint8_t byte){
    switch(byte){
      case 'q':
        WDTCTL = 0x00;
        break;

      case 's':
        post sample();
        break;

      case 'r':
        repeatSample = !repeatSample;
        printf("Repeat sample: %x\r\n", repeatSample);
        break;

      case '\r':
        printf("\r\n");
        break;
      default:
        printf("%c", byte);
    }
  }

  async command const msp430adc12_channel_config_t* AdcConfigure.getConfiguration(){
    return &config;
  }

  //unused
  async event error_t Msp430Adc12SingleChannel.singleDataReady(uint16_t data){
    printf("!singleDataReady\r\n");
    return SUCCESS;
  }

  async event void UartStream.receiveDone( uint8_t* buf_, uint16_t len,
    error_t error ){}
  async event void UartStream.sendDone( uint8_t* buf_, uint16_t len,
    error_t error ){
  }
}
