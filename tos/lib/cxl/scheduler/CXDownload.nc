interface CXDownload {
  command error_t startDownload();
  event void downloadFinished();
} 
