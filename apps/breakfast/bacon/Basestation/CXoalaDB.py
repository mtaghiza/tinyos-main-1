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

from lpp import LppMoteIF

from autoPush.listeners import RecordListener
from autoPush.listeners import PrintfListener
from autoPush.listeners import PongListener
from autoPush.messages import PrintfMsg
from autoPush.messages import LogRecordDataMsg
from autoPush.messages import CxRecordRequestMsg
from autoPush.messages import PingMsg
from autoPush.messages import PongMsg

from autoPush.db import Database

from autoPush.decoders import BaconSample

class Dispatcher(object):
    def __init__(self, motestring, bsId, db):
        #hook up to mote
        self.mif = LppMoteIF.LppMoteIF()
        self.tos_source = self.mif.addSource(motestring)
        #format printf's correctly
        self.mif.addListener(PrintfListener.PrintfListener(bsId), 
          PrintfMsg.PrintfMsg)
        self.mif.addListener(RecordListener.RecordListener(db), 
          LogRecordDataMsg.LogRecordDataMsg)
        self.mif.addListener(PongListener.PongListener(), 
          PongMsg.PongMsg)
        #ugh: not guaranteed that the serial connection is fully
        # opened by this point
        time.sleep(1)

    def stop(self):
        self.mif.finishAll()

    def send(self, m, dest=0):
        self.mif.send(dest, m)

def download(packetSource, bsId, wakeupLen, repairLimit, nodeList):
    print packetSource
    db = Database.Database()
    d = Dispatcher(packetSource, bsId, db)
    db.addDecoder(BaconSample.BaconSample)
    pingId = 0

    try:
        print "Wakeup start", time.time()
        #phase 1: wakeup
        d.mif.wakeup(bsId, wakeupLen)

        print "Autopush", time.time()
        #phase 2: clear outstanding buffers
        for node in nodeList:
            rxc = 0
            response = True
            ping = PingMsg.PingMsg()
            ping.set_pingId(pingId)
            localTime = time.time()
            d.send(ping, node)
            print "Ping %u id %u at %.2f"%(node, pingId, localTime)
            pingId += 1
            time.sleep(1)
            while response:
                d.mif.wakeup(bsId)
                response = d.mif.readFrom(node, 2.1)
                if not response:
                    print "No response from %u"%(node,)
                else:
                    rxc += 1
                    print "RX %u from %u"%(rxc, node)
            print "Done with ", node
        
        print "Recovery", time.time()
        #phase 3: recovery
        request_list = db.findMissing()
        MAX_PACKET_PAYLOAD = 100
        #for request in request_list:
        repairs = 0
        while request_list and (repairLimit == 0 or repairs < repairLimit):
            print "Recovery requests: ", request_list
            for request in request_list:
                #keep-alive
                d.mif.wakeup(bsId)
    
                msg = CxRecordRequestMsg.CxRecordRequestMsg()
                msg.set_node_id(request['node_id'])
                msg.set_cookie(request['nextCookie'])
                
                if request['missing'] < MAX_PACKET_PAYLOAD:
                    msg.set_length(request['missing'])
                else:
                    msg.set_length(MAX_PACKET_PAYLOAD)
                print "requesting %u at %u from %u"%(msg.get_length(),
                  msg.get_cookie(), msg.get_node_id())
                
                d.send(msg, msg.get_node_id())
                #need to allow the request to go out before we issue
                # the cts, and we don't have a good way to block on
                # this operation.
                time.sleep(1)
                d.mif.readFrom(request['node_id'], 2.1)
            request_list = db.findMissing()
            repairs += 1
        else:
            print "No repairs needed"
        print "Sleep", time.time()
        #done: back to sleep.
        d.mif.sleep(bsId)
        #debug: give the mote a couple of seconds to finish up
        # anything it's doing
        time.sleep(5)
        print "Done", time.time()

    #these two exceptions should just make us clean up/quit
    except KeyboardInterrupt:
        pass
    except EOFError:
        pass
    finally:
        print "Cleaning up"
        d.stop()

if __name__ == '__main__':
    if len(sys.argv) < 4:
        print "Usage:", sys.argv[0], "packetSource(e.g.  serial@/dev/ttyUSB0:115200) bsId wakeupLen, repairLimit=0" 
        sys.exit()

    packetSource = sys.argv[1]
    bsId = int(sys.argv[2])
    wakeupLen = int(sys.argv[3])
    repairLimit = 0
    if len(sys.argv) > 4:
        repairLimit = int(sys.argv[4])
    download(packetSource, bsId, wakeupLen, repairLimit, [1])
