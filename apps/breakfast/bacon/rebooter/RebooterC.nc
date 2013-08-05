configuration RebooterC{
} implementation {
  components MainC;
  components new TimerMilliC();
  components RandomC;

  components RebooterP;
  RebooterP.Timer -> TimerMilliC;
  RebooterP.Boot -> MainC;
  RebooterP.Random -> RandomC;
}
