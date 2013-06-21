#!/usr/bin/env python

import sys, time
from mig import PrintfMsg, TestPayload
from lpp import LppMoteIF

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

    def receive(self, src, msg):
        if not self.quiet:
            print msg

class Dispatcher:
    def __init__(self, motestring, quiet=False):
        self.quiet = quiet
        self.sendCount = 0
        #hook up to mote + LPP control hooks
        self.mif = LppMoteIF.LppMoteIF()
        print "Source: %s"%motestring
        self.mif.addSource(motestring)
#         #format printf's correctly
        self.mif.addListener(PrintfLogger(), PrintfMsg.PrintfMsg)
        self.mif.addListener(GenericLogger(self.quiet), TestPayload.TestPayload)
        #grrrr shouldn't be needed
        time.sleep(2.0)

    def stop(self):
        self.mif.finishAll()

    def send(self, m, dest=0):
        if not self.quiet:
            print "Sending",self.sendCount, m
        self.mif.send(dest, m)
        self.sendCount += 1


nodeList = range(2)

if __name__ == '__main__':
    packetSource = 'serial@/dev/ttyUSB0:115200'

    if len(sys.argv) < 5:
        print "Usage:", sys.argv[0], "packetSource", "bsId", "sleepPeriod(s)", "wakeupLen" 
        sys.exit()

    packetSource = sys.argv[1]
    bsId = int(sys.argv[2])
    sleepPeriod = int(sys.argv[3])
    wakeupLen = int(sys.argv[4])
    last = None

    d = Dispatcher(packetSource, quiet=False)

    try:
        while True:
            d.mif.wakeup(bsId, wakeupLen)
            rxc = 0
            for node in nodeList:
                response = True
                while response:
                    d.mif.wakeup(bsId)
                    response = d.mif.readFrom(node)
                    if not response:
                        print "No response from %u"%(node,)
                    else:
                        rxc += 1
                        print "RX %u from %u"%(rxc, node)
                print "Done with ", node
            print "Sleeping."
            d.mif.sleep(bsId)
            time.sleep(sleepPeriod)
    
    #these two exceptions should just make us clean up/quit
    except KeyboardInterrupt:
        pass
    except EOFError:
        pass
    finally:
        print "Cleaning up"
        d.stop()


