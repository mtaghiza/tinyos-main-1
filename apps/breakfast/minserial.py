#!/usr/bin/env python

# Copyright (c) 2014 Johns Hopkins University
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# - Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
# - Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the
#   distribution.
# - Neither the name of the copyright holders nor the names of
#   its contributors may be used to endorse or promote products derived
#   from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
# THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.

import serial
import sys

class MinPort(object):
    def __init__(self, port, baud):
        self.sp = serial.Serial(port, 
            9600, 
            parity=serial.PARITY_EVEN,
            timeout=None)

    def flushInput(self):
        print "flush in"
        self.sp.flushInput()

    def flushOutput(self):
        print "flush out"
        self.sp.flushOutput()

    def setRSTn(self, value=1):
        print "setting RSTn to %d"%value
        self.sp.setRTS(not value)

    def read(self, numbytes=1):
        print "reading %d"%numbytes
        return self.sp.read(numbytes)

    def write(self, data):
        print "writing %s"%data
        return self.sp.write(data)

def flushAndStart(mp):
    mp.flushInput()
    mp.flushOutput()
    mp.setRSTn(1)

if __name__ == '__main__':
    port = "/dev/ttyUSB0"
    baud = 115200
    if len(sys.argv) > 1:
        port = sys.argv[1]
    if len(sys.argv) > 2:
        baud = sys.argv[2]
    mp = MinPort(port, int(baud))
    flushAndStart(mp)
    print mp.read(1)
    print mp.write("hi")
    #in this config, read works, we can stop/start by writing to RSTn
    #unfortunately, connecting *will* cause it to restart
