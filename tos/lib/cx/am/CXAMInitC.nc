configuration CXAMInitC{
  uses interface ActiveMessageAddress;
} implementation {
  components MainC;
  components CXAMInitP;
  
  components GlobalIDC;
  CXAMInitP.GlobalID -> GlobalIDC;
  MainC.SoftwareInit -> CXAMInitP;
  
  CXAMInitP.ActiveMessageAddress = ActiveMessageAddress;
}
