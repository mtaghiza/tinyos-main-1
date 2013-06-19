#!/usr/bin/env python

import sys, time, thread
from threading import Lock, Condition
import Queue

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
    def __init__(self, quiet, queue):
        self.quiet = quiet
        self.queue = queue

    def receive(self, src, msg):
        self.queue.put(msg)
        if not self.quiet:
            print msg

class Dispatcher:
    def __init__(self, motestring, quiet=False):
        self.queue = Queue.Queue()
        self.quiet = quiet
        self.sendCount = 0
        #hook up to mote
        self.mif = MoteIF.MoteIF()
        print "Source: %s"%motestring
        self.tos_source = self.mif.addSource(motestring)
#         #format printf's correctly
        self.mif.addListener(PrintfLogger(), PrintfMsg.PrintfMsg)
        self.mif.addListener(GenericLogger(self.quiet, self.queue), TestPayload.TestPayload)
        #grrrr shouldn't be needed
        time.sleep(2.0)

    def stop(self):
        self.mif.finishAll()

    def receive(self, timeout=None):
        try:
            if timeout:
                return self.queue.get(True, timeout)
            else:
                return self.queue.get(False)
        except Queue.Empty:
            return None

    def send(self, m, dest=0):
        if not self.quiet:
            print "Sending",self.sendCount, m
        self.mif.sendMsg(self.tos_source,
            dest,
            m.get_amType(), 0,
            m)
        self.sendCount += 1


nodeList = [1]

class Logger(object):
    def __init__(self, out):
        self.out = out

    def logPacket(self, msg):
        self.out.write("%0.2f %u %s"%(time.time(), msg.addr, str(msg))) 

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
    l = Logger(sys.stdout)
    d = Dispatcher(packetSource, quiet=False)
    try:
        while True:
            wakeup = CxLppWakeup.CxLppWakeup()
            #failsafe: if the base station goes 10 seconds without
            # getting an explicit keep-awake, it will put the network
            # to sleep.
            wakeup.set_timeout(10240)
            
            wakeupDone = time.time() + wakeupLen
            while time.time() < wakeupDone:
                d.send(wakeup, bsId)
                time.sleep(1)

            for node in nodeList:
                response = True
                while response:
                    d.send(wakeup, bsId)
                    cts = CxLppCts.CxLppCts()
                    cts.set_addr(node)
                    print "CTS to ", node
                    d.send(cts, node)
                    response = d.receive(1.0)
                    #TODO: validate that this response is from the
                    # correct node.
                    if response:
                        l.logPacket(response)
                    else:
                        print "(no response)"
                print "Done with ", node
            print "Sleeping."
            sleep = CxLppSleep.CxLppSleep()
            sleep.set_delay(0)
            d.send(sleep, bsId)
            time.sleep(sleepPeriod)

    
    #these two exceptions should just make us clean up/quit
    except KeyboardInterrupt:
        pass
    except EOFError:
        pass
    finally:
        print "Cleaning up"
        d.stop()


