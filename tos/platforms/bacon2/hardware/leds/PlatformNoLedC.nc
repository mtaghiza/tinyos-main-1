module PlatformNoLedC {
  provides interface Init;
}implementation{
  command error_t Init.init(){
    //original pin config handles this
    return SUCCESS;
  }
}
