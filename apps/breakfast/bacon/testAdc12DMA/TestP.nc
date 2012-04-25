
 #include <stdio.h>
 #include "decodeError.h"

module TestP{
  uses interface Boot;
  uses interface UartStream;
  uses interface StdControl as SerialControl;
  uses interface SplitControl as SamplerControl;

  uses interface Sampler;

  provides interface AdcConfigure<const msp430adc12_channel_config_t*>;
} implementation {

  
  #ifndef SAMPLE_INTERVAL
  #define SAMPLE_INTERVAL 650
  #endif

  bool isSampling = FALSE;

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
    printf(" q: reset\r\n");
  }

  event void Boot.booted(){
    P1SEL &= ~BIT1;
    P1OUT &= ~BIT1;
    P1DIR |= BIT1;

    call SerialControl.start();
    call SamplerControl.start();
  }

  event void SamplerControl.startDone(error_t error){
    post printWelcome();
  }

  event uint16_t* Sampler.burstDone(uint16_t* buffer){
    if (isSampling){
      printf(".");
      return buffer;
    } else {
      return NULL;
    }
  }

  task void sample(){
    if (!isSampling){
      printf("START");
      isSampling = TRUE;
      call Sampler.startSampling(SAMPLE_INTERVAL);
    }
  }

  task void stop(){
    isSampling = FALSE;
    printf("STOP\r\n");
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
  event void SamplerControl.stopDone(error_t error){
  }
  async event void UartStream.receiveDone( uint8_t* buf_, uint16_t len,
    error_t error ){}
  async event void UartStream.sendDone( uint8_t* buf_, uint16_t len,
    error_t error ){
  }
}
