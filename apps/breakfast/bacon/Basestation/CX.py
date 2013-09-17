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
from autoPush.messages import CxRecordRequestMsg

from autoPush.db import Database

from autoPush.decoders import BaconSample
from autoPush.decoders import ToastSample
from autoPush.decoders import BaconSettings
from autoPush.decoders import ToastConnection
from autoPush.decoders import ToastDisconnection
from autoPush.decoders import Phoenix
from autoPush.decoders import LogPrintf
from autoPush.decoders import NetworkMembership
from cx.decoders import Tunneled

from cx.messages import CxDownload
from cx.CXMoteIF import CXMoteIF

from cx.messages import StatusTimeRef
from cx.listeners import StatusTimeRefListener

from cx import constants

from cx.messages import SetBaconSampleInterval
from cx.messages import SetToastSampleInterval

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
        self.mif.configureMoteRadio(bsId, configFile)
        time.sleep(1)
        self.mif.configureMaxDownloadRounds(bsId, configFile)


    def stop(self):
        self.mif.clearRXQueue()
        time.sleep(1)
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
    db.addDecoder(LogPrintf.LogPrintf)
    db.addDecoder(NetworkMembership.NetworkMembership)
    #man that is ugghly to hook 
    t = db.addDecoder(Tunneled.Tunneled)
    t.receiveQueue = d.mif.receiveQueue
    pingId = 0

    refListener = StatusTimeRefListener.StatusTimeRefListener(db.dbName)
    d.mif.addListener(refListener, StatusTimeRef.StatusTimeRef)

    try:
        print "Wakeup start", time.time()

        
        downloadMsg = CxDownload.CxDownload()
        downloadMsg.set_networkSegment(networkSegment)
        t0 = time.time() 
        error = d.send(downloadMsg, bsId)
        refListener.downloadStart = (time.time() + t0)/2
#         #TESTING 
#         setBSI = SetBaconSampleInterval.SetBaconSampleInterval(2*60*1024)
#         #send it via broadcast
#         error = d.send(setBSI, 0xFFFF)
#         setTSI = SetToastSampleInterval.SetToastSampleInterval(60*1024)
#         error = d.send(setTSI, 0xFFFF)
#         #END TESTING
        
        request_list = db.findMissing()
#         request_list = []
        print "Recovery requests: ", request_list
#         MAX_PACKET_PAYLOAD = 100
        for request in request_list:
            if request['node_id'] != bsId:
                msg = CxRecordRequestMsg.CxRecordRequestMsg()
                msg.set_node_id(request['node_id'])
                msg.set_cookie(request['nextCookie'])
                msg.set_length(min(request['missing'], constants.MAX_REQUEST_UNIT))
    #             if request['missing'] < MAX_PACKET_PAYLOAD:
    #                 msg.set_length(request['missing'])
    #             else:
    #                 msg.set_length(MAX_PACKET_PAYLOAD)
                print "requesting %u at %u from %u"%(msg.get_length(),
                  msg.get_cookie(), msg.get_node_id())
                error = d.send(msg, msg.get_node_id())
                print "Request status: %x"%error
                if error:
                    break
            else:
                print "Skip BS pseudo-cookie"

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

def pushConfig(packetSource, bsId, networkSegment, configFile,
      newConfigFile, nodeList):
    db = Database.Database()
    d = Dispatcher(packetSource, bsId, db, configFile)
    #we will get status refs in this process
    refListener = StatusTimeRefListener.StatusTimeRefListener(db.dbName)
    d.mif.addListener(refListener, StatusTimeRef.StatusTimeRef)

    #Should not be receiving other types of data here.
    db.addDecoder(NetworkMembership.NetworkMembership)
    try:
        downloadMsg = CxDownload.CxDownload()
        downloadMsg.set_networkSegment(networkSegment)
        t0 = time.time() 
        error = d.send(downloadMsg, bsId)
        refListener.downloadStart = (time.time() + t0)/2

        if error:
            print "Download failed: %x"%error
            pass
        else: 
            for node in nodeList:
                d.mif.configureMoteRadio(node, newConfigFile)
            d.mif.downloadWait()

    except KeyboardInterrupt:
        pass
    except EOFError:
        pass
    finally:
        print "Cleaning up"
        d.stop()

def ping(packetSource, bsId, networkSegment, configFile):
    db = Database.Database()
    d = Dispatcher(packetSource, bsId, db, configFile)
    #we will get status refs in this process
    refListener = StatusTimeRefListener.StatusTimeRefListener(db.dbName)
    d.mif.addListener(refListener, StatusTimeRef.StatusTimeRef)

    #Should not be receiving other types of data here.
    db.addDecoder(NetworkMembership.NetworkMembership)
    try:
        downloadMsg = CxDownload.CxDownload()
        downloadMsg.set_networkSegment(networkSegment)
        t0 = time.time() 
        error = d.send(downloadMsg, bsId)
        refListener.downloadStart = (time.time() + t0)/2

        if error:
            print "Ping failed: %x"%error
            pass
        else: 
            d.mif.downloadWait()

    except KeyboardInterrupt:
        pass
    except EOFError:
        pass
    finally:
        print "Cleaning up"
        d.stop()

def sleep(packetSource, bsId, networkSegment, configFile, sleepDuration):
    print "Sleeping for %f" % sleepDuration
    db = Database.Database()
    d = Dispatcher(packetSource, bsId, db, configFile)
    try:
        time.sleep(sleepDuration)
    finally:
        print "Cleaning up"
        d.stop()

def triggerRouterDownload(packetSource, bsId, networkSegment, configFile):
    db = Database.Database()
    d = Dispatcher(packetSource, bsId, db, configFile)
    #we will get status refs in this process
    refListener = StatusTimeRefListener.StatusTimeRefListener(db.dbName)
    d.mif.addListener(refListener, StatusTimeRef.StatusTimeRef)

    db.addDecoder(BaconSample.BaconSample)
    db.addDecoder(ToastSample.ToastSample)
    db.addDecoder(ToastConnection.ToastConnection)
    db.addDecoder(ToastDisconnection.ToastDisconnection)
    db.addDecoder(Phoenix.Phoenix)
    db.addDecoder(BaconSettings.BaconSettings)
    db.addDecoder(LogPrintf.LogPrintf)
    db.addDecoder(NetworkMembership.NetworkMembership)
    #man that is ugghly to hook 
    t = db.addDecoder(Tunneled.Tunneled)
    t.receiveQueue = d.mif.receiveQueue

    #Should not be receiving other types of data here.
    db.addDecoder(NetworkMembership.NetworkMembership)
    try:
        downloadMsg = CxDownload.CxDownload()
        downloadMsg.set_networkSegment(networkSegment)
        t0 = time.time() 
        error = d.send(downloadMsg, bsId)
        refListener.downloadStart = (time.time() + t0)/2


        if error:
            print "BS download failed: %x"%error
            pass
        else: 
            downloadMsg.set_networkSegment(constants.NS_SUBNETWORK)
            time.sleep(1)
            error = d.send(downloadMsg, 0xFFFF)
            print "Router download command: ",error
            if error:
                print "Router download failed"
            else:
                d.mif.downloadWait()

    except KeyboardInterrupt:
        pass
    except EOFError:
        pass
    finally:
        print "Cleaning up"
        d.stop()

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print "Usage:", sys.argv[0], "packetSource(e.g serial@/dev/ttyUSB0:115200) bsId [networkSegment] [configFile] [-p newConfigFile [node]*] [--ping]" 
        print "  [networkSegment=0] : 0=global 1=subnetwork 2=router"
        print "  -p: push configFile settings to nodes listed"
        sys.exit()

    packetSource = sys.argv[1]
    bsId = int(sys.argv[2])
    networkSegment = constants.NS_GLOBAL
    configFile = None
    if len(sys.argv) > 3:
        networkSegment = int(sys.argv[3])
    if len(sys.argv) > 4:
        configFile = sys.argv[4]

    if '-p' in sys.argv:
        pIndex= sys.argv.index('-p')
        nodeList = [int(s, 16) for s in sys.argv[pIndex+2:] if s.startswith('0x')]
        nodeList += [int(s) for s in sys.argv[pIndex+2:] if not s.startswith('0x')]
        newConfigFile = sys.argv[pIndex+1]
        print "Pushing config %s to %s"%(newConfigFile, nodeList)
        pushConfig(packetSource, bsId, networkSegment, configFile, newConfigFile, nodeList)
    elif '--ping' in sys.argv:
        ping(packetSource, bsId, networkSegment, configFile)
    elif '--routerDownload' in sys.argv:
        triggerRouterDownload(packetSource, bsId, networkSegment, configFile)
    elif '--download' in sys.argv:
        download(packetSource, bsId, networkSegment, configFile)

    if '--sleep' in sys.argv:
        sleepDuration = float(sys.argv[sys.argv.index('--sleep')+1])
        sleep(packetSource, bsId, networkSegment, configFile, sleepDuration)

