#
# Copyright (c) 2005-2006
#      The President and Fellows of Harvard College.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of the University nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE UNIVERSITY AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE UNIVERSITY OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# Author: Geoffrey Mainland <mainland@eecs.harvard.edu>
#
import serial

from IO import *

class SerialIO(IO):
    def __init__(self, device, baud):
        IO.__init__(self)
        
        self.device = device
        self.baud = baud
    
    def open(self):
        self.serial = serial.Serial(port=self.device,
                                    baudrate=self.baud)
        self.serial.flushInput()
        self.serial.flushOutput()
        self.serial.close()
        self.serial = serial.Serial(port=self.device,
                                    baudrate=self.baud)

    
    def close(self):
        self.done = True
        self.serial.close()
    
    def read(self, count):
        if self.isDone():
            raise IODone()

        while self.serial.inWaiting() < count:
            if self.isDone():
                raise IODone()
        
        return self.serial.read(count)
    
    def write(self, data):
        return self.serial.write(data)
    
    def flush(self):
        print >>sys.stderr, "Flushing the serial port",
#         self.serial.flushInput()
#         endtime = time.time() + 1
#         while time.time() < endtime:
#             self._s.read()
#             sys.stdout.write(".")
#         sys.stdout.write("\n")
#         self.serial.flushOutput()

