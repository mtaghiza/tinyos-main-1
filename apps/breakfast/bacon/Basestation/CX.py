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
from autoPush.decoders import ToastSample
from autoPush.decoders import BaconSettings
from autoPush.decoders import ToastConnection
from autoPush.decoders import ToastDisconnection
from autoPush.decoders import Phoenix
from cx.decoders import Tunneled

from cx.messages import CxDownload
from cx.CXMoteIF import CXMoteIF

from cx.messages import StatusTimeRef
from cx.listeners import StatusTimeRefListener

from cx import constants

class Dispatcher(object):
    def __init__(self, motestring, bsId, db, configFile):
        #hook up to mote
        self.mif = CXMoteIF(bsId)
        self.tos_source = self.mif.addSource(motestring)
        #format printf's correctly
        self.mif.addListener(PrintfListener.PrintfListener(bsId), 
          PrintfMsg.PrintfMsg)
        self.mif.addListener(RecordListener.RecordListener(db), 
          LogRecordDataMsg.LogRecordDataMsg)
        self.mif.addListener(PongListener.PongListener(), 
          PongMsg.PongMsg)
        self.mif.configureBasestation(configFile)

    def stop(self):
        self.mif.finishAll()

    def send(self, m, dest=0, requireAck=True):
        return self.mif.send(dest, m, requireAck)

def download(packetSource, bsId, networkSegment=constants.NS_GLOBAL, configFile=None):
    print packetSource
    db = Database.Database()
    d = Dispatcher(packetSource, bsId, db, configFile)
    db.addDecoder(BaconSample.BaconSample)
    db.addDecoder(ToastSample.ToastSample)
    db.addDecoder(ToastConnection.ToastConnection)
    db.addDecoder(ToastDisconnection.ToastDisconnection)
    db.addDecoder(Phoenix.Phoenix)
    db.addDecoder(BaconSettings.BaconSettings)
    #man that is ugghly to hook 
    t = db.addDecoder(Tunneled.Tunneled)
    t.receiveQueue = d.mif.receiveQueue
    pingId = 0

    refListener = StatusTimeRefListener.StatusTimeRefListener()
    d.mif.addListener(refListener, StatusTimeRef.StatusTimeRef)

    try:
        print "Wakeup start", time.time()

        request_list = db.findMissing()
        
        t0 = time.time() 
        downloadMsg = CxDownload.CxDownload()
        refListener.downloadStart = (time.time() + t0)/2
        downloadMsg.set_networkSegment(networkSegment)

        error = d.send(downloadMsg, bsId)
        if error:
            print "Download failed: %x"%error
            pass
        else: 
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
        print "Usage:", sys.argv[0], "packetSource(e.g. serial@/dev/ttyUSB0:115200) bsId [networkSegment] [configFile]" 
        print "  [networkSegment=0] : 0=global 1=subnetwork 2=router"
        sys.exit()

    packetSource = sys.argv[1]
    bsId = int(sys.argv[2])
    networkSegment = constants.NS_GLOBAL
    configFile = None
    if len(sys.argv) > 3:
        networkSegment = int(sys.argv[3])
    if len(sys.argv) > 4:
        configFile = sys.argv[4]
    download(packetSource, bsId, networkSegment, configFile)
