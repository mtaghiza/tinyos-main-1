interface CXDownload {
  command error_t startDownload(uint8_t ns);
  event void downloadFinished();
} 
