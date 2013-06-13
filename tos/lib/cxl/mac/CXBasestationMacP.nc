module CXBasestationMacP{
  provides interface CXMacController;
  //TODO: need an interface to instruct this when to send CTS packets
}implementation {
  //Base station is always allowed to send, so just grant the request.
  task void signalGranted(){
    signal CXMacController.requestGranted();
  }

  command error_t CXMacController.requestSend(){
    post signalGranted();
  }
}
