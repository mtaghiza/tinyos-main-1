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

from tools.cx.listeners import RecordListener
from tools.cx.listeners import PrintfListener
from tools.cx.messages import PrintfMsg
from tools.cx.messages import LogRecordDataMsg

from tools.cx.messages import CxRecordRequestMsg

from tools.cx.db import Database
from tools.cx.db.DatabaseInit import DatabaseInit

from tools.cx.decoders import BaconSample
from tools.cx.decoders import ToastSample
from tools.cx.decoders import BaconSettings
from tools.cx.decoders import ToastConnection
from tools.cx.decoders import ToastDisconnection
from tools.cx.decoders import Phoenix
from tools.cx.decoders import LogPrintf
from tools.cx.decoders import NetworkMembership
from tools.cx.decoders import Tunneled

from tinyos.message import *
from tinyos.message.Message import *
from tinyos.message.SerialPacket import *
from tinyos.packet.Serial import Serial

import threading
import random



class Dispatcher:
    def __init__(self, motestring, db):
        #hook up to mote
        self.mif = MoteIF.MoteIF()
        self.tos_source = self.mif.addSource(motestring)
        #format printf's correctly
        self.mif.addListener(PrintfListener.PrintfListener(0), 
          PrintfMsg.PrintfMsg)
        self.mif.addListener(RecordListener.RecordListener(db), 
          LogRecordDataMsg.LogRecordDataMsg)

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
    DatabaseInit('database')
    db = Database.Database('database0.sqlite')
    d = Dispatcher(packetSource, db)
    db.addDecoder(BaconSample.BaconSample)
    db.addDecoder(ToastSample.ToastSample)
    db.addDecoder(ToastConnection.ToastConnection)
    db.addDecoder(ToastDisconnection.ToastDisconnection)
    db.addDecoder(Phoenix.Phoenix)
    db.addDecoder(BaconSettings.BaconSettings)
    db.addDecoder(LogPrintf.LogPrintf)
    db.addDecoder(NetworkMembership.NetworkMembership)
    t = db.addDecoder(Tunneled.Tunneled)
    t.receiveQueue = d.mif.receiveQueue

    try:
        msg = CxRecordRequestMsg.CxRecordRequestMsg()
        msg.set_node_id(0xFFFF)
        msg.set_cookie(0)
        msg.set_length(50000)
        d.send(msg)                
        lastLastCookie = -1
        while True:
            time.sleep(2.0)
            #the dummy parameters are here because executeNow expects
            # parameters. whoops.
            ((lastCookie,),) = db.insert.executeNow('''
            SELECT nextCookie from cookie_table
              WHERE base_time = (select max(base_time) from
              cookie_table) AND 1=? and 1=?''', (1,1))
            print "LAST COOKIE:", lastCookie
            if lastCookie == lastLastCookie:
                print "No log progress, I guess we're done!"
                break
            else:
                msg.set_node_id(0xFFFF)
                msg.set_cookie(lastCookie)
                msg.set_length(50000)
                d.send(msg) 
                lastLastCookie = lastCookie
    #these two exceptions should just make us clean up/quit
    except KeyboardInterrupt:
        pass
    except EOFError:
        pass
    finally:
        print "Cleaning up"
        d.stop()
        db.stop()

