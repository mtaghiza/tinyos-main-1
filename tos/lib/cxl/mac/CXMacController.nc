interface CXMacController {
  command error_t requestSend();
  event void requestGranted();
}
