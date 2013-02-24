#!/usr/bin/env python
import sys
import time

import mig
from mig import *

from tinyos.message import *
from tinyos.message.Message import *
from tinyos.message.SerialPacket import *
from tinyos.packet.Serial import Serial


class PrintfLogger(object):
    def __init__(self):
        self.buf=''
        pass
    
    def receive(self, src, msg):
        mb = msg.get_buffer()
        if 0 in mb:
            mb = mb[:mb.index(0)]
        sys.stdout.write(''.join(chr(v) for v in mb))


class RecordIterator(object):
    COOKIE_LEN = 4
    LENGTH_LEN = 1
    
    def val(self, arr):
        return reduce(lambda l, r: (l<<8) + r, arr, 0)

    def __init__(self, recordMsg):
        self.data = recordMsg.get_data()
        self.si = 0

    def __iter__(self):
        return self

    def next(self):
        while self.si < len(self.data):
            cookieBytes = self.data[self.si:self.si+RecordIterator.COOKIE_LEN]
            self.si += RecordIterator.COOKIE_LEN
            if cookieBytes == [0xff, 0xff, 0xff, 0xff]:
                raise StopIteration
            cookieVal = self.val(cookieBytes)
            lenVal = self.val(self.data[self.si:self.si+RecordIterator.LENGTH_LEN])
            self.si += RecordIterator.LENGTH_LEN
            recordData = self.data[self.si:self.si + lenVal]
            self.si += lenVal
            return (cookieVal, lenVal, recordData)
        raise StopIteration


class GenericLogger(object):
    def __init__(self):
        pass

    def receive(self, src, msg):
        print msg
        for record in RecordIterator(msg):
            print "#",record


class Dispatcher:
    def __init__(self, motestring):
        #hook up to mote
        self.mif = MoteIF.MoteIF()
        self.tos_source = self.mif.addSource(motestring)
        #format printf's correctly
        self.mif.addListener(PrintfLogger(), PrintfMsg.PrintfMsg)
        self.mif.addListener(GenericLogger(), LogRecordDataMsg.LogRecordDataMsg)
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

    timeout = 0

    if len(sys.argv) < 1:
        print "Usage:", sys.argv[0], "[packetSource=serial@/dev/ttyUSB0:115200] [destination=0x01]" 
        sys.exit()

    if len(sys.argv) > 1:
        packetSource = sys.argv[1]
    if len(sys.argv) > 2:
        destination = int(sys.argv[2], 16)
    if len(sys.argv) > 3:
        timeout = float(sys.argv[3])/1024.0 + 120
    start = time.time()
    
    print packetSource
    d = Dispatcher(packetSource)

    try:
        while (timeout == 0) or time.time() < timeout + start:
            pass
        print "OK, times up"
    #these two exceptions should just make us clean up/quit
    except KeyboardInterrupt:
        pass
    except EOFError:
        pass
    finally:
        print "Cleaning up"
        d.stop()

