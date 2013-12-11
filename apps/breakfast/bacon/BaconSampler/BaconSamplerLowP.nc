
 #include "Msp430Adc12.h"
 #include "BaconSampler.h"
module BaconSamplerLowP{
  uses interface Boot;
  uses interface LogWrite;
  uses interface Timer<TMilli>;
  uses interface Timer<TMilli> as WarmupTimer;
  uses interface SettingsStorage;
} implementation {

  MSP430REG_NORACE(ADC12CTL0);
  MSP430REG_NORACE(ADC12CTL1);
  MSP430REG_NORACE(ADC12IFG);
  MSP430REG_NORACE(ADC12IE);
  MSP430REG_NORACE(ADC12IV);

  DEFINE_UNION_CAST(int2adc12ctl0,adc12ctl0_t,uint16_t)
  DEFINE_UNION_CAST(int2adc12ctl1,adc12ctl1_t,uint16_t)
  DEFINE_UNION_CAST(adc12ctl0cast2int,uint16_t,adc12ctl0_t)
  DEFINE_UNION_CAST(adc12ctl1cast2int,uint16_t,adc12ctl1_t)
  DEFINE_UNION_CAST(adc12memctl2int,uint8_t,adc12memctl_t)
  DEFINE_UNION_CAST(int2adc12memctl,adc12memctl_t,uint8_t)

  enum {
    BATTERY = 0,
    LIGHT = 1,
    THERMISTOR = 2,
  };
  uint8_t step = BATTERY;
  bacon_sample_t sampleRec = {
    .recordType = RECORD_TYPE_BACON_SAMPLE,
    .rebootCounter = 0,
    .baseTime = 0,
    .battery = 0,
    .light = 0
  };

  event void Boot.booted(){
//    nx_uint32_t sampleInterval;
//    sampleInterval = DEFAULT_SAMPLE_INTERVAL;
//    #if CONFIGURABLE_BACON_SAMPLE_INTERVAL == 1
//    call SettingsStorage.get(SS_KEY_BACON_SAMPLE_INTERVAL,
//      (uint8_t*)(&sampleInterval), sizeof(sampleInterval));
//    #endif
    call SettingsStorage.get(SS_KEY_REBOOT_COUNTER,
      (uint8_t*)(&sampleRec.rebootCounter), 
      sizeof(sampleRec.rebootCounter));
    call Timer.startOneShot(INITIAL_SAMPLE_DELAY);
  }
  
  task void readBattery();
  event void Timer.fired(){
    nx_uint32_t sampleInterval;
    sampleInterval = DEFAULT_SAMPLE_INTERVAL;
    sampleRec.baseTime = call Timer.getNow();
    #if CONFIGURABLE_BACON_SAMPLE_INTERVAL == 1
    call SettingsStorage.get(SS_KEY_BACON_SAMPLE_INTERVAL,
      (uint8_t*)(&sampleInterval), sizeof(sampleInterval));
    #endif
    call Timer.startOneShotAt(call Timer.gett0() + call Timer.getdt(), sampleInterval);
    sampleRec.battery = 0x0000;
    sampleRec.light = 0x0000;
    post readBattery();
  }

  adc12ctl1_t initCtl1;
  adc12memctl_t initMemctl;
  adc12ctl0_t initCtl0;

  task void readBattery(){
    adc12ctl1_t ctl1 = {
      adc12busy: 0,
      conseq: 0,
      adc12ssel: SHT_SOURCE_ACLK,
      adc12div: SHT_CLOCK_DIV_1,
      issh: 0,
      shp: 1,
      shs: 0,
      cstartadd: 0
    };
    adc12memctl_t memctl = {
      inch: INPUT_CHANNEL_A0,
      sref: REFERENCE_VREFplus_AVss,
      eos: 1
    };        
    adc12ctl0_t ctl0 = {
      adc12sc: 0,
      enc: 0,
      adc12tovie: 0,
      adc12ovie: 0,
      adc12on: 1,
      refon: 1,
      r2_5v: 1,
      msc: 0,
      sht0: 0x0,
      sht1: 0x0
    };
    initCtl1 = int2adc12ctl1(ADC12CTL1);
    initCtl0 = int2adc12ctl0(ADC12CTL0);
    initMemctl = int2adc12memctl(ADC12MCTL[0]);

    P2SEL |= BIT0;
    P2DIR &= ~BIT0;
    PJDIR |= BIT2;
    PJOUT |= BIT2;
    REFCTL0 &= ~ REFMSTR;
    ADC12CTL0 &= ~BIT1;
    ADC12CTL0 = adc12ctl0cast2int(ctl0); 
    ADC12CTL1 = adc12ctl1cast2int(ctl1); 
    ADC12MCTL[0] = adc12memctl2int(memctl);
    step = BATTERY;
    call WarmupTimer.startOneShot(1);
  }

  event void WarmupTimer.fired(){
    ADC12IE = BIT0;
    ADC12CTL0 |= ADC12ON | ENC | ADC12SC; // Start conversion
  }

  task void readLight(){
    adc12ctl1_t ctl1 = {
      adc12busy: 0,
      conseq: 0,
      adc12ssel: SHT_SOURCE_ACLK,
      adc12div: SHT_CLOCK_DIV_1,
      issh: 0,
      shp: 1,
      shs: 0,
      cstartadd: 0
    };
    adc12memctl_t memctl = {
      inch: INPUT_CHANNEL_A2,
      sref: REFERENCE_VREFplus_AVss,
      eos: 1
    };        
    adc12ctl0_t ctl0 = {
      adc12sc: 0,
      enc: 0,
      adc12tovie: 0,
      adc12ovie: 0,
      adc12on: 1,
      refon: 1,
      r2_5v: 1,
      msc: 0,
      sht0: 0x0,
      sht1: 0x0
    };
    P2SEL |= BIT2;
    P2DIR &= ~BIT2;
    REFCTL0 &= ~ REFMSTR;
    ADC12CTL0 &= ~BIT1;
    ADC12CTL0 = adc12ctl0cast2int(ctl0); 
    ADC12CTL1 = adc12ctl1cast2int(ctl1); 
    ADC12MCTL[0] = adc12memctl2int(memctl);
    P3SEL &= ~BIT3;
    P3DIR |= BIT3;
    P3OUT |= BIT3;
    step = LIGHT;
    call WarmupTimer.startOneShot(1);
  }

  task void readThermistor(){
    adc12ctl1_t ctl1 = {
      adc12busy: 0,
      conseq: 0,
      adc12ssel: SHT_SOURCE_ACLK,
      adc12div: SHT_CLOCK_DIV_1,
      issh: 0,
      shp: 1,
      shs: 0,
      cstartadd: 0
    };
    adc12memctl_t memctl = {
      inch: INPUT_CHANNEL_A5,
      sref: REFERENCE_VREFplus_AVss,
      eos: 1
    };        
    adc12ctl0_t ctl0 = {
      adc12sc: 0,
      enc: 0,
      adc12tovie: 0,
      adc12ovie: 0,
      adc12on: 1,
      refon: 1,
      r2_5v: 1,
      msc: 0,
      sht0: 0x0,
      sht1: 0x0
    };
    P2SEL |= BIT5;
    P2DIR &= ~BIT5;
    REFCTL0 &= ~ REFMSTR;
    ADC12CTL0 &= ~BIT1;
    ADC12CTL0 = adc12ctl0cast2int(ctl0); 
    ADC12CTL1 = adc12ctl1cast2int(ctl1); 
    ADC12MCTL[0] = adc12memctl2int(memctl);
    PJDIR |= BIT1;
    PJOUT |= BIT1;
    step = THERMISTOR;
    call WarmupTimer.startOneShot(1);
  }

  task void append(){
    ADC12IE &= ~BIT0;
    ADC12CTL0 &= ~(ADC12ON | ENC | ADC12SC);
    ADC12CTL0 = adc12ctl0cast2int(initCtl0);   
    ADC12CTL1 = adc12ctl1cast2int(initCtl1);   
    ADC12MCTL[0] = adc12memctl2int(initMemctl);   
    call LogWrite.append(&sampleRec, sizeof(sampleRec));
  }

  norace uint16_t conversionResult;

  task void conversionDone(){
    switch (step){
      case BATTERY:
        sampleRec.battery = conversionResult;
  //      printf("b %x %x %x\r\n", ADC12CTL0, ADC12CTL1, ADC12MCTL[0]);
        PJOUT &= ~BIT2;
        P2SEL &= ~BIT0;
        P2OUT &= ~BIT0;
        P2DIR |= BIT1;
        post readLight();
        break;
      case LIGHT: 
        sampleRec.light = conversionResult;
  //      printf("l %x %x %x\r\n", ADC12CTL0, ADC12CTL1, ADC12MCTL[0]);
        P3OUT &= ~BIT3;
        P2SEL &= ~BIT2;
        P2DIR |= BIT2;
        P2OUT &= ~BIT2;
        post readThermistor();
        break;
      case THERMISTOR:
        sampleRec.thermistor = conversionResult;
        PJOUT &= ~BIT1;
        P2SEL &= ~BIT5;
        P2DIR |= BIT5;
        P2OUT &= ~BIT5;
        post append();
        break;
      default:
        //pass
    }
  }


  TOSH_SIGNAL(ADC12_VECTOR) {
    conversionResult = ADC12MEM0;
    post conversionDone();
  }

  event void LogWrite.eraseDone(error_t error){}
  event void LogWrite.syncDone(error_t error){}
  event void LogWrite.appendDone(void* buf, storage_len_t len, 
    bool recordsMaybeLost, error_t error){}
}
