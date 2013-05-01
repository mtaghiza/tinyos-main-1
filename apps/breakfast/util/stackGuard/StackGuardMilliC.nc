configuration StackGuardMilliC{
} implementation {
  components StackGuardMilliP as StackGuardP;
  components new TimerMilliC();
  components LedsC;

  components MainC;
  
  StackGuardP.Timer -> TimerMilliC;
  MainC.SoftwareInit -> StackGuardP.Init;
  StackGuardP.Leds -> LedsC;
}

