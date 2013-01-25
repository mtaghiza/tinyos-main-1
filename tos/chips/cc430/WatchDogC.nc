configuration WatchDogC{
} implementation{
  components new TimerMilliC();
  components WatchDogP;
  components MainC;
  
  WatchDogP <- MainC.SoftwareInit;
  WatchDogP.Timer -> TimerMilliC;
}
