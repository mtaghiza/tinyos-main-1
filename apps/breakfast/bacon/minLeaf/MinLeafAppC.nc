configuration MinLeafAppC{
} implementation {
  components MainC;
  components MinLeafP;
  components CXLeafC;
  components ActiveMessageC;

  MinLeafP.SplitControl -> ActiveMessageC;
  MinLeafP.Boot -> MainC;
}
