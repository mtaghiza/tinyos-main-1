
#ifndef USE_ALARM 
#define USE_ALARM 0
#endif

#ifndef USE_MICRO_TIMER
#define USE_MICRO_TIMER 0
#endif

#ifndef USE_32KHZ_TIMER
#define USE_32KHZ_TIMER 0
#endif

#ifndef TEST_BUSY 
#define TEST_BUSY 0
#endif

#if USE_SERIAL == 1
#include <stdio.h>
#else
#define printf(...)
#endif

configuration TestAppC{
} implementation {
  components MainC;
  components LedsC;

  #if USE_ALARM == 1
  #warning "using real alarm"
  components new AlarmMicro32C() as Alarm;
  #else
  #warning "using dummy alarm"
  components DummyAlarmMicro32C as Alarm;
  #endif
  
  #if USE_SERIAL == 1
  #warning "using real serial"
  components PlatformSerialC;
  components SerialPrintfC;
  #else
  #warning "using dummy serial"
  components DummyPlatformSerialC as PlatformSerialC;
  #endif

  components Msp430XV2ClockC;
  
  components new TestP(USE_ALARM,
    USE_MICRO_TIMER,
    USE_32KHZ_TIMER,
    TEST_BUSY,
    (6347UL*ALARM_MILLIS)
    + (ALARM_MILLIS/32UL)*21);
  TestP.Boot -> MainC;
  TestP.Alarm -> Alarm;
  TestP.Leds -> LedsC;
  TestP.Msp430XV2ClockControl -> Msp430XV2ClockC;

  TestP.StdControl -> PlatformSerialC;
}
