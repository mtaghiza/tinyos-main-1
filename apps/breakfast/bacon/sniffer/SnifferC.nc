configuration SnifferC {}
implementation {
  components MainC, SnifferP as App, LedsC;
  components new TimerMilliC();
  components ActiveMessageC;
  components Rf1aActiveMessageC;
  components PlatformSerialC;
  

  #if SYMBOLRATE == 50
  components Rf1aConfig50KC as Rf1aSettings;
  #elif SYMBOLRATE == 100
  components Rf1aConfig100KC as Rf1aSettings;
  #elif SYMBOLRATE == 125
  components SRFS7_915_GFSK_125K_SENS_HC as Rf1aSettings;
  #elif SYMBOLRATE == 250
  components Rf1aConfig250KC as Rf1aSettings;
  #else
  #error Unrecognized symbol rate
  #endif
//  components SRFS7_915_GFSK_100K_SENS_HC as Rf1aSettings;

  Rf1aActiveMessageC.Rf1aConfigure 
    -> Rf1aSettings;

  
  App.Boot -> MainC.Boot;
  
  App.AMControl -> ActiveMessageC;
  App.Leds -> LedsC;
  App.MilliTimer -> TimerMilliC;


  App.SerialControl -> PlatformSerialC;
  components SerialPrintfC;

  components Rf1aDumpConfigC;
//  App.Rf1aConfigure -> Rf1aSettings;
  App.Rf1aDumpConfig -> Rf1aDumpConfigC;
  App.Rf1aPhysical -> Rf1aActiveMessageC;
}


