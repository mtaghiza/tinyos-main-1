
 #include "CXDownload.h"

interface CXDownload {
  command error_t startDownload();
  event void downloadFinished();
  event void eos(am_addr_t owner, eos_status_t status);
  command error_t markPending(am_addr_t node);
} 
