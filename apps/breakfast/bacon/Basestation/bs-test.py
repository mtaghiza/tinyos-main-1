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


