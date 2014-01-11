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

from tinyos.message import *
from tinyos.message.Message import *
from tinyos.message.SerialPacket import *
from tinyos.packet.Serial import Serial
#import tos
import mig
from mig import *

import math



class GenericLogger:
    def __init__(self):
        pass

    def receive(self, src, msg):
        print msg


class Dispatcher:
    def __init__(self, motestring):
        self.sendCount = 0
        self.mif = MoteIF.MoteIF()
        self.tos_source = self.mif.addSource(motestring)
        for messageClass in mig.__all__:
            if 'Response' in messageClass:
                self.mif.addListener(GenericLogger(), 
                  getattr(getattr(mig, messageClass), messageClass))

    def stop(self):
        self.mif.finishAll()

    def send(self, m, dest=0):
        print "Sending",self.sendCount, m
        self.mif.sendMsg(self.tos_source,
            dest,
            m.get_amType(), 0,
            m)
        self.sendCount += 1
    

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
    
    print packetSource, destination

    d = Dispatcher(packetSource)
    last = None
    time.sleep(1)
    try:
        #set (0x99, 1)
        s = SetSettingsStorageMsg.SetSettingsStorageMsg()
        s.set_key(0x99)
        s.set_len(1)
        s.set_val([1])
        d.send(s, destination)
        time.sleep(0.25)
        
        #get(0x99) -> 1
        g = GetSettingsStorageCmdMsg.GetSettingsStorageCmdMsg()
        g.set_key(0x99)
        g.set_len(1)
        d.send(g, destination)
        time.sleep(0.25)
        
        #set (0x99, 2)
        s.set_val([2])
        d.send(s, destination)
        time.sleep(0.25)

        #get (0x99) -> 2
        d.send(g, destination)
        time.sleep(0.25)
        
        c = ClearSettingsStorageMsg.ClearSettingsStorageMsg()
        c.set_key(0x99)
        d.send(c, destination)
        time.sleep(0.25)
        
        #get(0x99) -> EINVAL
        d.send(g, destination)
        time.sleep(0.25)

    #these two exceptions should just make us clean up/quit
    except KeyboardInterrupt:
        pass
    except EOFError:
        pass
    finally:
        print "Cleaning up"
        d.stop()

