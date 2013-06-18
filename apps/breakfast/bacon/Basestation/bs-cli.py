#!/usr/bin/env python

import sys, time, thread
from threading import Lock, Condition

from tinyos.message import *
from tinyos.message.Message import *
from tinyos.message.SerialPacket import *
from tinyos.packet.Serial import Serial
#import tos
import mig
from mig import *

import math


class PrintfLogger(object):
    def __init__(self):
        self.buf=''
        pass
    
    def receive(self, src, msg):
        mb = msg.get_buffer()
        if 0 in mb:
            mb = mb[:mb.index(0)]
        sys.stdout.write(''.join(chr(v) for v in mb))

class GenericLogger(object):
    def __init__(self, quiet):
        self.quiet = quiet
        pass

    def receive(self, src, msg):
        if not self.quiet:
            print msg

class Dispatcher:
    def __init__(self, motestring, quiet=False):
        self.quiet = quiet
        self.sendCount = 0
        #hook up to mote
        self.mif = MoteIF.MoteIF()
        print "Source: %s"%motestring
        self.tos_source = self.mif.addSource(motestring)
#         #format printf's correctly
        self.mif.addListener(PrintfLogger(), PrintfMsg.PrintfMsg)
        self.mif.addListener(GenericLogger(self.quiet), TestPayload.TestPayload)

    def stop(self):
        self.mif.finishAll()

    def send(self, m, dest=0):
        if not self.quiet:
            print "Sending",self.sendCount, m
        self.mif.sendMsg(self.tos_source,
            dest,
            m.get_amType(), 0,
            m)
        self.sendCount += 1

    def initialize(self, destination):
        pass


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

    last = None
    d = Dispatcher(packetSource, quiet=False)
    try:
        d.initialize(destination)
        while True:
            time.sleep(0.25)
            mcn = raw_input('''Input message class name (q to quit, blank to resend last). 
Choices: 
    %s\n?> '''%('\n    '.join(v for v in mig.__all__ )))
            if not last and not mcn:
                continue
            if last and not mcn:
                d.send(last, destination)
                continue
            if mcn not in mig.__all__:
                for cn in mig.__all__:
                    if cn.startswith(mcn):
                        mcn = cn
                        break
            if mcn in mig.__all__:           
                m = getattr(getattr(mig, mcn), mcn)()
                #ugh, these should be exposed with __set__, __get__ so
                # that it looks like dictionary access
                for setter in [s for s in dir(m) if s.startswith('set_')]:
                    if setter == 'set_dummy':
                        v = []
#                         elif setter == 'set_tag':
#                             continue
                    else:
                        v = eval(raw_input('%s:'%setter),
                          {"__builtins__":None}, {})
                        print v
                    getattr(m, setter)(v)
                d.send(m, destination)
                last = m
            if mcn == 'q':
                break
    
    #these two exceptions should just make us clean up/quit
    except KeyboardInterrupt:
        pass
    except EOFError:
        pass
    finally:
        print "Cleaning up"
        d.stop()

