configuration CXAMAddressC{
  provides interface ActiveMessageAddress;
} implementation {
  components Ieee154AMAddressC;
  ActiveMessageAddress = Ieee154AMAddressC;

  #ifndef AM_ID_FROM_FLASH
  #define AM_ID_FROM_FLASH 1
  #endif

  #if AM_ID_FROM_FLASH == 1
  components CXAMInitC;
  CXAMInitC.ActiveMessageAddress -> Ieee154AMAddressC;
  #else
  #warning "Using TOS_NODE_ID as AM ID (TEST ONLY)"
  #endif
}
