configuration CXAMAddressC{
  provides interface ActiveMessageAddress;
} implementation {
  components Ieee154AMAddressC;
  ActiveMessageAddress = Ieee154AMAddressC;
}
