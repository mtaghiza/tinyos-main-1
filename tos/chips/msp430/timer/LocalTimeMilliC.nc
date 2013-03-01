configuration LocalTimeMilliC{
  provides interface LocalTime<TMilli>;
} implementation {
  components HilTimerMilliC;
  LocalTime = HilTimerMilliC;
}
