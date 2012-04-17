configuration StackGuardC{
} implementation {
  components StackGuardP;
  //for best results, we want to keep all the state in the peripheral
  //registers (well away from the dynamic stack)
  components new Alarm32khz16C();
  components LedsC;

  components MainC;
  
  StackGuardP.Alarm -> Alarm32khz16C;
  MainC.SoftwareInit -> StackGuardP.Init;
  StackGuardP.Leds -> LedsC;
}
