interface CXMacController {
  command error_t requestSend(message_t* msg);
  event void requestGranted();
}
