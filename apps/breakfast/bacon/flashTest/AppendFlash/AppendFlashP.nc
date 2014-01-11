/*
 * Copyright (c) 2014 Johns Hopkins University.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
*/

module AppendFlashP
{
  uses {
    interface Boot;
    interface LogWrite;
    interface LogRead;
    interface Leds;
  }
}

implementation
{
  typedef nx_struct LogEntry {
    nx_uint8_t led;
  } LogEntry;
  
  LogEntry entry;
  
  event void Boot.booted()
  {
    entry.led = 2;
    if (call LogWrite.append(&entry, sizeof(LogEntry)) == SUCCESS) {
      call Leds.led1On();
    } else {
      call Leds.led0On();
    }
  }
  
  event void LogRead.readDone(void* buf, 
                              storage_len_t len, 
                              error_t error)
  {
    if (buf == &entry && len == sizeof(LogEntry)) {
      switch (entry.led) {
        case 0:
          call Leds.led0On();
          break;
        case 1:
          call Leds.led1On();
          break;
        case 2:
          call Leds.led2On();
          break;
      }
    }
  }
  event void LogRead.seekDone(error_t error) {}
  
  event void LogWrite.syncDone(error_t error) {}
  
  event void LogWrite.eraseDone(error_t error) {}
  event void LogWrite.appendDone(void* buf,
                                 storage_len_t len,
                                 bool recordsLost,
                                 error_t error)
  {
    call Leds.led1Off();
    if (call LogRead.read(&entry, sizeof(LogEntry)) != SUCCESS) {
      call Leds.led0On();
    }
  }
}
