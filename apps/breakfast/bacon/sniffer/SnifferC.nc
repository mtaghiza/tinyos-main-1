configuration SnifferC {}
implementation {
  components MainC, SnifferP as App, LedsC;
  components new TimerMilliC();
  components ActiveMessageC;
  components Rf1aActiveMessageC;
  

//  components SRFS7_915_GFSK_125K_SENS_HC as Rf1aSettings;
//  components Rf1aConfig100KC as Rf1aSettings;
  //TODO: switch at compile time
  components SRFS7_915_GFSK_100K_SENS_HC as Rf1aSettings;

  Rf1aActiveMessageC.Rf1aConfigure 
    -> Rf1aSettings;

  
  App.Boot -> MainC.Boot;
  
  App.AMControl -> ActiveMessageC;
  App.Leds -> LedsC;
  App.MilliTimer -> TimerMilliC;


  components StdOutC;
  App.SerialControl -> StdOutC;
  App.StdOut -> StdOutC;

  components Rf1aDumpConfigC;
//  App.Rf1aConfigure -> Rf1aSettings;
  App.Rf1aDumpConfig -> Rf1aDumpConfigC;
  App.Rf1aPhysical -> Rf1aActiveMessageC;
}


