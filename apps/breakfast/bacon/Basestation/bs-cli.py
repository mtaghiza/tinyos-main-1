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

