#!/usr/bin/env python

import sys, time, thread

from tinyos.message import *
from tinyos.message.Message import *
from tinyos.message.SerialPacket import *
from tinyos.packet.Serial import Serial
#import tos
import mig
from mig import *


class PrintfLogger:
    def __init__(self):
        self.buf=''
        pass
    
    def receive(self, src, msg):
        mb = msg.get_buffer()
        if 0 in mb:
            mb = mb[:mb.index(0)]
        sys.stdout.write(''.join(chr(v) for v in mb))

class GenericLogger:
    def __init__(self):
        pass

    def receive(self, src, msg):
        print msg


class Dispatcher:
    def __init__(self, motestring):
        self.mif = MoteIF.MoteIF()
        self.tos_source = self.mif.addSource(motestring)
        self.mif.addListener(PrintfLogger(), PrintfMsg.PrintfMsg)
        for messageClass in mig.__all__:
            if 'Response' in messageClass:
                self.mif.addListener(GenericLogger(), 
                  getattr(getattr(mig, messageClass), messageClass))

    def stop(self):
        self.mif.finishAll()

    def send(self, m, dest=0):
        print "Sending",m
        self.mif.sendMsg(self.tos_source,
            dest,
            m.get_amType(), 0,
            m)

if __name__ == '__main__':
    #TODO: unclear why serial@/dev/ttyUSBx:115200 doesn't work.
    #Seems like the python serial libraries from TOS don't support raw
    # serial access: would need something that implements PacketSource
    # methods and just uses the python serial libs to read/write
    # directly.
    packetSource = 'sf@localhost:9002'

    if len(sys.argv) < 1:
        print "Usage:", sys.argv[0], "[packetSource=sf@localhost:9002]" 
        sys.exit()

    if len(sys.argv) > 1:
        packetSource = sys.argv[1]

    print packetSource

    d = Dispatcher(packetSource)
    last = None
    time.sleep(1)
    try:
        while True:
            time.sleep(0.25)
            mcn = raw_input('''Input message class name (q to quit, blank to resend last). 
  Choices: 
    %s\n?> '''%('\n    '.join(v for v in mig.__all__ if 'Cmd' in v)))
            if not last and not mcn:
                continue
            if last and not mcn:
                d.send(last)
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
                    else:
                        v = eval(raw_input('%s:'%setter),
                          {"__builtins__":None}, {})
                        print v
                    getattr(m, setter)(v)
                d.send(m)
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

