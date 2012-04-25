
 #include <stdio.h>
 #include "decodeError.h"

module TestP{
  uses interface Boot;
  uses interface UartStream;
  uses interface StdControl as SerialControl;

  uses interface Sampler;
  uses interface SplitControl as SamplerControl;

  uses interface Timer<TMilli>;

  provides interface AdcConfigure<const msp430adc12_channel_config_t*>;
} implementation {
  uint32_t sampleCount;
  uint32_t startTime;
  
  #ifndef SAMPLE_INTERVAL
  #define SAMPLE_INTERVAL 650
  #endif

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
    printf("ADC12 Test\r\n");
    printf(" s: start sampling\r\n");
    printf(" S: stop sampling\r\n");
    printf(" r: read back\r\n");
    printf(" q: reset\r\n");
  }

  event void Boot.booted(){
    P2DIR |= BIT1;
    P2SEL &= ~BIT1;
    P2OUT |= BIT1;

    call SerialControl.start();
    call SamplerControl.start();
  }

  event void SamplerControl.startDone(error_t error){
    post printWelcome();
  }

  event void Sampler.burstDone(uint16_t numSamples){
    sampleCount += numSamples;
  }

  task void sample(){
    printf("START");
    startTime = call Timer.getNow();
    call Sampler.startSampling(SAMPLE_INTERVAL, TRUE);
  }

  task void resume(){
    printf("RESUME");
    call Sampler.startSampling(SAMPLE_INTERVAL, FALSE);
  }

  task void stop(){
    uint32_t stopTime;
    printf("STOPPING\r\n");
    call Sampler.stopSampling();
    //why is this causing it to crash?
//    uint32_t duration = call Timer.getNow() - startTime;
//    printf("STOP: %lu samples in %lu bms\r\n",
//      sampleCount, duration);
//      sampleCount/(duration/1024));
  }
 
  #ifndef RB_BUFFER_LEN
  #define RB_BUFFER_LEN 8
  #endif

  uint32_t endAddr;
  uint32_t addr;
  uint16_t readBackBuffer[RB_BUFFER_LEN];

  uint32_t rbc;
  
  task void readNext(){
    call Sampler.read(addr, (uint8_t*)readBackBuffer,
      sizeof(uint16_t)*RB_BUFFER_LEN);
  }

  event void Sampler.readDone(uint32_t addr_, uint8_t* buf, 
      uint16_t count, error_t error){
    uint8_t i;
    for (i = 0; i < RB_BUFFER_LEN; i++){
      printf("%lu %u\r\n", rbc, readBackBuffer[i]);
      rbc++;
    }
    if (addr_ < endAddr){
      addr = addr_ + count;
      post readNext();
    }
  }

  task void readBack(){
    endAddr = call Sampler.getEnd();
    rbc=0;
    addr=0;
    post readNext();
  }

  async event void UartStream.receivedByte(uint8_t byte){
    switch(byte){
      case 'q':
        WDTCTL = 0x00;
        break;

      case 's':
        post sample();
        break;

      case 'S':
        post stop();
        break;
      
      case 'r':
        post readBack();
        break;

      case '\r':
        printf("\r\n");
        break;
      default:
        printf("%c", byte);
    }
  }

  event void Timer.fired(){}

  async command const msp430adc12_channel_config_t* AdcConfigure.getConfiguration(){
    return &config;
  }
  event void SamplerControl.stopDone(error_t error){
  }
  async event void UartStream.receiveDone( uint8_t* buf_, uint16_t len,
    error_t error ){}
  async event void UartStream.sendDone( uint8_t* buf_, uint16_t len,
    error_t error ){
  }
}
