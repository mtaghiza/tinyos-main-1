#!/usr/bin/env python
import sys
import time

from tinyos.message.MoteIF import MoteIF

from autoPush.listeners import RecordListener
from autoPush.listeners import PrintfListener
from autoPush.messages import PrintfMsg
from autoPush.messages import LogRecordDataMsg

from autoPush.listeners import PongListener
from autoPush.messages import PongMsg
from autoPush.messages import PingMsg

from autoPush.db import Database

from autoPush.decoders import BaconSample

from cx.messages import CxDownload
from cx.CXMoteIF import CXMoteIF

class Dispatcher(object):
    def __init__(self, motestring, bsId, db):
        #hook up to mote
        self.mif = CXMoteIF()
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

def download(packetSource, bsId):
    print packetSource
    db = Database.Database()
    d = Dispatcher(packetSource, bsId, db)
    db.addDecoder(BaconSample.BaconSample)
    pingId = 0

    try:
        print "Wakeup start", time.time()

        request_list = db.findMissing()

        downloadMsg = CxDownload.CxDownload()

        #TODO: read channel from...?
        downloadMsg.set_channel(0)
        d.send(downloadMsg, bsId)

        ping = PingMsg.PingMsg()
        ping.set_pingId(pingId)
        localTime = time.time()
        print "pinging"
        d.send(ping, 1)
        
        #TODO: we should send repair requests out first (since
        #  controller gets to go first)

        d.mif.downloadWait()

    #these two exceptions should just make us clean up/quit
    except KeyboardInterrupt:
        pass
    except EOFError:
        pass
    finally:
        print "Cleaning up"
        d.stop()

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print "Usage:", sys.argv[0], "packetSource(e.g.  serial@/dev/ttyUSB0:115200) bsId" 
        sys.exit()

    packetSource = sys.argv[1]
    bsId = int(sys.argv[2])
    download(packetSource, bsId)
