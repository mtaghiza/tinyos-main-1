#!/usr/bin/env python
import sys
import time
import ast

from tools.labeler.TOS import TOS
from tools.cx.listeners import RecordListener
from tools.cx.listeners import PrintfListener
from tools.cx.messages import PrintfMsg
from tools.cx.messages import LogRecordDataMsg

from tools.cx.listeners import PongListener
from tools.cx.messages import PongMsg
from tools.cx.messages import PingMsg
from tools.cx.messages import CxRecordRequestMsg

from tools.cx.db import Database

from tools.cx.decoders import BaconSample
from tools.cx.decoders import ToastSample
from tools.cx.decoders import BaconSettings
from tools.cx.decoders import ToastConnection
from tools.cx.decoders import ToastDisconnection
from tools.cx.decoders import Phoenix
from tools.cx.decoders import LogPrintf
from tools.cx.decoders import NetworkMembership
from tools.cx.decoders import Tunneled

from tools.cx.messages import CxStatus
from tools.cx.CXMoteIF import CXMoteIF

from tools.cx.listeners import StatusTimeRefListener

from tools.cx import constants

from tools.cx.messages import SetBaconSampleInterval
from tools.cx.messages import SetToastSampleInterval


class Dispatcher(object):
    def __init__(self, motestring, db, configMap={},
      configFile=None):
        #hook up to mote
        self.mif = CXMoteIF()
        self.tos_source = self.mif.addSource(motestring)
        if self.mif.identifyMote():
            #format printf's correctly
            self.mif.addListener(PrintfListener.PrintfListener(self.mif.bsId), 
              PrintfMsg.PrintfMsg)
            self.mif.addListener(RecordListener.RecordListener(db), 
              LogRecordDataMsg.LogRecordDataMsg)
            self.mif.addListener(PongListener.PongListener(), 
              PongMsg.PongMsg)
            if configFile:
                #evaluate each key:=value pair and stick it into config
                with open(configFile, 'r') as f:
                    for line in f:
                        if not line.startswith('#'):
                            r = line.split(':=')
                            configMap[r[0]] = ast.literal_eval(r[1])
            self.mif.configureMoteRadio(self.mif.bsId, configMap)
            time.sleep(1)
            self.mif.configureMaxDownloadRounds(self.mif.bsId, configMap)
        else:
            raise Exception("Connected mote did not respond to ID request (has it been set up as a BaseStation?")


    def stop(self):
        print "clearing"
        self.mif.clearRXQueue()
        print "cleared"
        self.mif.finishAll()
        print "finished"

    def send(self, m, dest=0):
        return self.mif.send(dest, m)

def download(packetSource, networkSegment=constants.NS_GLOBAL,
        configMap={}, configFile=None, refCallBack=None,
        finishedCallBack=None, requestMissing=True):
    print packetSource
    db = Database.Database()
    try:
        d = Dispatcher(packetSource, db, configMap=configMap, configFile=configFile)
        bsId = d.mif.bsId
    except:
        if finishedCallBack:
            finishedCallBack(constants.BCAST_ADDR, """Could not connect to base station.
  Make sure you've selected the right device and make sure
  it has been set up as a base station.
""") 
            raise
        else:
            raise

    db.addDecoder(BaconSample.BaconSample)
    db.addDecoder(ToastSample.ToastSample)
    db.addDecoder(ToastConnection.ToastConnection)
    db.addDecoder(ToastDisconnection.ToastDisconnection)
    db.addDecoder(Phoenix.Phoenix)
    db.addDecoder(BaconSettings.BaconSettings)
    db.addDecoder(LogPrintf.LogPrintf)
    db.addDecoder(NetworkMembership.NetworkMembership)
#     #man that is ugghly to hook 
#     t = db.addDecoder(Tunneled.Tunneled)
#     t.receiveQueue = d.mif.receiveQueue
    pingId = 0

    refListener = StatusTimeRefListener.StatusTimeRefListener(db, refCallBack)
    d.mif.addListener(refListener, CxStatus.CxStatus)

    try:
        print "Wakeup start", time.time()

        refListener.downloadStart = d.mif.downloadStart(bsId, 
          networkSegment)
        error = TOS.SUCCESS
        #TODO: add readNext to MoteIF
        #  - should block on an EOS message
        #  - if the message says "download finished" then we're done
        #  - if the message indicates a node was contacted and it had
        #    no data left at the end of the slot, then check for gaps
        #    in its data
        #  - if gaps are found, then construct the request and put it
        #    in

        if requestMissing:
            (request_list, allGaps)  = db.findMissing()
            print "Recovery requests: ", request_list
            print "All gaps: ", allGaps
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
        else:
            print "Skip recovery"

        if error:
            print "Download failed: %x"%error
            pass
        else: 
            #TODO: we should send repair requests out first (since
            #  controller gets to go first)
            print "starting download wait"
            d.mif.downloadWait()
            print "ending download wait"

    #these two exceptions should just make us clean up/quit
    except KeyboardInterrupt:
        pass
    except EOFError:
        pass
    finally:
        print "Cleaning up"
        d.stop()
        db.stop()
    print "done for real"
    if finishedCallBack:
        finishedCallBack(d.mif.bsId, "Finished.\n")

def pushConfig(packetSource, networkSegment, configFile,
      newConfigFile, nodeList):
    db = Database.Database()
    d = Dispatcher(packetSource, db, configFile=configFile)
    bsId = d.mif.bsId
    #we will get status refs in this process
    refListener = StatusTimeRefListener.StatusTimeRefListener(db.dbName)
    d.mif.addListener(refListener, StatusTimeRef.StatusTimeRef)

    #Should not be receiving other types of data here.
    db.addDecoder(NetworkMembership.NetworkMembership)
    try:
        refListener.downloadStart = d.mif.downloadStart(bsId,
          networkSegment)

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

def ping(packetSource, networkSegment, configFile):
    db = Database.Database()
    d = Dispatcher(packetSource, db, configFile=configFile)
    bsId = d.mif.bsId
    #we will get status refs in this process
    refListener = StatusTimeRefListener.StatusTimeRefListener(db.dbName)
    d.mif.addListener(refListener, StatusTimeRef.StatusTimeRef)

    #Should not be receiving other types of data here.
    db.addDecoder(NetworkMembership.NetworkMembership)
    try:
        refListener.downloadStart = d.mif.downloadStart(bsId,
          networkSegment)

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

def sleep(packetSource, networkSegment, configFile, sleepDuration):
    print "Sleeping for %f" % sleepDuration
    db = Database.Database()
    d = Dispatcher(packetSource, db, configFile=configFile)
    bsId = d.mif.bsId
    try:
        time.sleep(sleepDuration)
    finally:
        print "Cleaning up"
        d.stop()
        db.stop()

def triggerRouterDownload(packetSource, networkSegment, configFile):
    db = Database.Database()
    d = Dispatcher(packetSource, db, configFile=configFile)
    bsId = d.mif.bsId
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
        refListener.downloadStart = d.mif.downloadStart(bsId,
          networkSegment)


        if error:
            print "BS download failed: %x"%error
            pass
        else: 
            downloadMsg = CxDownload.CxDownload()
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
        print "Usage:", sys.argv[0], "packetSource(e.g serial@/dev/ttyUSB0:115200) [networkSegment] [configFile] [-p newConfigFile [node]*] [--ping]" 
        print "  [networkSegment=0] : 0=global 1=subnetwork 2=router"
        print "  -p: push configFile settings to nodes listed"
        sys.exit()

    packetSource = sys.argv[1]
    networkSegment = constants.NS_GLOBAL
    configFile = None
    
#     if len(sys.argv) > 2:
#         networkSegment = int(sys.argv[2])
#     if len(sys.argv) > 3:
#         configFile = sys.argv[3]
    if '--segment' in sys.argv:
        networkSegment = int(sys.argv[sys.argv.index('--segment')+1])
    if '--configFile' in sys.argv:
        configFile = sys.argv[sys.argv.index('--configFile')+1]

    if '-p' in sys.argv:
        pIndex= sys.argv.index('-p')
        nodeList = [int(s, 16) for s in sys.argv[pIndex+2:] if s.startswith('0x')]
        nodeList += [int(s) for s in sys.argv[pIndex+2:] if not s.startswith('0x')]
        newConfigFile = sys.argv[pIndex+1]
        print "Pushing config %s to %s"%(newConfigFile, nodeList)
        pushConfig(packetSource, networkSegment, configFile, newConfigFile, nodeList)
    elif '--ping' in sys.argv:
        ping(packetSource, networkSegment, configFile)
    elif '--routerDownload' in sys.argv:
        triggerRouterDownload(packetSource, networkSegment, configFile)
    elif '--download' in sys.argv:
        download(packetSource, networkSegment, configFile=configFile)

    if '--sleep' in sys.argv:
        sleepDuration = float(sys.argv[sys.argv.index('--sleep')+1])
        sleep(packetSource, networkSegment, configFile, sleepDuration)

