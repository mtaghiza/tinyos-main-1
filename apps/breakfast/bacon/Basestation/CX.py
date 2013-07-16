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
from cx.decoders import Tunneled

from cx.messages import CxDownload
from cx.CXMoteIF import CXMoteIF

from cx.messages import StatusTimeRef
from cx.listeners import StatusTimeRefListener

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
        self.mif.addListener(StatusTimeRefListener.StatusTimeRefListener(),
          StatusTimeRef.StatusTimeRef)

    def stop(self):
        self.mif.finishAll()

    def send(self, m, dest=0):
        self.mif.send(dest, m)

NS_GLOBAL=0
NS_SUBNETWORK=1
NS_ROUTER=2

def download(packetSource, bsId, networkSegment=NS_GLOBAL):
    print packetSource
    db = Database.Database()
    d = Dispatcher(packetSource, bsId, db)
    db.addDecoder(BaconSample.BaconSample)
    #man that is ugghly to hook 
    t = db.addDecoder(Tunneled.Tunneled)
    t.receiveQueue = d.mif.receiveQueue
    pingId = 0

    try:
        print "Wakeup start", time.time()

        request_list = db.findMissing()

        downloadMsg = CxDownload.CxDownload()
        downloadMsg.set_networkSegment(networkSegment)

        d.send(downloadMsg, bsId)

#         ping = PingMsg.PingMsg()
#         ping.set_pingId(pingId)
#         localTime = time.time()
#         print "pinging"
#         d.send(ping, 1)
        
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
        print "Usage:", sys.argv[0], "packetSource(e.g.  serial@/dev/ttyUSB0:115200) bsId [networkSegment]" 
        print "  [networkSegment=0] : 0=global 1=subnetwork 2=router"
        sys.exit()

    packetSource = sys.argv[1]
    bsId = int(sys.argv[2])
    networkSegment = NS_GLOBAL
    if len(sys.argv) > 3:
        networkSegment = int(sys.argv[3])
    download(packetSource, bsId, networkSegment)
