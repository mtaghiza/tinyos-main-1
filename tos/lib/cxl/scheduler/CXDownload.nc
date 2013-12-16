
 #include "CXDownload.h"

interface CXDownload {
  command error_t startDownload();
  event void downloadFinished();
  event void eos(am_addr_t owner, eos_status_t status);
  event void nextAssignment(am_addr_t owner, 
    bool dataPending, uint8_t failedAttempts);
  command error_t markPending(am_addr_t node);
} 
