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

import sys
import time

import mig
from mig import *

from tinyos.message import *
from tinyos.message.Message import *
from tinyos.message.SerialPacket import *
from tinyos.packet.Serial import Serial

from RecordIterator import RecordIterator

def toUnsigned(arr, lsbFirst=True):
    inc = -1 if lsbFirst else 1
    return reduce(lambda l, r: (l <<8) + r, arr[::inc], 0)

class PrintfLogger(object):
    def __init__(self):
        self.buf=''
        pass
    
    def receive(self, src, msg):
        mb = msg.get_buffer()
        if 0 in mb:
            mb = mb[:mb.index(0)]
        sys.stdout.write(''.join(chr(v) for v in mb))

class SensorSampleLogger(object):
    def __init__(self):
        pass

    def receive(self, record):
        #TODO: this should be using struct.unpack
        (cookieVal, lenVal, recordType, recordData) = record
        rc = toUnsigned(recordData[0:2])
        #TODO bt should be signed (though it should always be
        # positive in practice)
        bt = toUnsigned(recordData[2:6])
        sa = recordData[6:14]
        recordData = recordData[14:]
        samples = []
        #TODO: if the extra byte after toast addr remains, handle it
        # here.
        while recordData:
            sr = recordData[:2]
            recordData=recordData[2:]
            sample = toUnsigned(sr)
            samples += [sample]
        print "# SAMPLE", rc, bt, bt/1024.0, sa, samples

class RecordLogger(object):
    def __init__(self):
        self.listeners={}
        pass

    def addListener(self, recordType, listener):
        self.listeners[recordType] = listener

    def receive(self, src, msg):
        print msg
        for (cookieVal, lenVal, recordData) in RecordIterator(msg):
            (recordType, recordData) = (recordData[0], recordData[1:])
            if recordType in self.listeners:
                self.listeners[recordType].receive( 
                  (cookieVal, lenVal, recordType, recordData))
            elif recordType != 0xFF:
                print "#",(cookieVal, lenVal, recordType, recordData)


class Dispatcher:
    def __init__(self, motestring):
        #hook up to mote
        self.mif = MoteIF.MoteIF()
        self.tos_source = self.mif.addSource(motestring)
        #format printf's correctly
        self.mif.addListener(PrintfLogger(), PrintfMsg.PrintfMsg)
        self.rl = RecordLogger()
        self.rl.addListener(0x12, SensorSampleLogger())
        self.mif.addListener(self.rl, LogRecordDataMsg.LogRecordDataMsg)
        #ugh: not guaranteed that the serial connection is fully
        # opened by this point
        time.sleep(1)

    def stop(self):
        self.mif.finishAll()

    def send(self, m, dest=0):
        self.mif.sendMsg(self.tos_source,
            dest,
            m.get_amType(), 0,
            m)

if __name__ == '__main__':
    packetSource = 'serial@/dev/ttyUSB0:115200'
    destination = 1

    if len(sys.argv) < 1:
        print "Usage:", sys.argv[0], "[packetSource=serial@/dev/ttyUSB0:115200] [destination=0x01]" 
        sys.exit()

    if len(sys.argv) > 1:
        packetSource = sys.argv[1]
    if len(sys.argv) > 2:
        destination = int(sys.argv[2], 16)
    
    print packetSource
    d = Dispatcher(packetSource)

    try:
        while True:
            pass
    #these two exceptions should just make us clean up/quit
    except KeyboardInterrupt:
        pass
    except EOFError:
        pass
    finally:
        print "Cleaning up"
        d.stop()

