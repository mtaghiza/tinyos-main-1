#!/usr/bin/env python
from tinyos.message.MoteIF import MoteIF
import Queue 
import time
import ast

from threading import Condition

from cx.listeners.CtrlAckListener import CtrlAckListener
from cx.messages.CtrlAck import CtrlAck

from cx.listeners.CxDownloadFinishedListener import CxDownloadFinishedListener
from cx.messages.CxDownloadFinished import CxDownloadFinished
from cx.messages import SetProbeSchedule

class MultipleSourceException(Exception):
    pass

class CXMoteIF(MoteIF):
    def __init__(self, bsId):
        MoteIF.__init__(self)
        self.ackQueue = Queue.Queue()
        self.addListener(CtrlAckListener(self.ackQueue),
          CtrlAck)
        self.finishedCV = Condition()
        self.addListener(CxDownloadFinishedListener(self.finishedCV),
          CxDownloadFinished)
        #TODO: less arbitrary. In fact, we should probably be waiting
        # until we get a downloadFinished. Might be helpful to add 
        # downloadOngoing / haltDownload packets?
        self.sendTimeout = 30
        self.retryLimit = 0
        self.source = None
        self.bsId = bsId

    def configureBasestation(self, configFile):
        #sensible defaults
        bsConfig = {
          'probeInterval': 1024,
          'globalChannel': 0,
          'subNetworkChannel': 32,
          'routerChannel': 64,
          'globalInvFrequency': 4,
          'subNetworkInvFrequency': 0,
          'routerInvFrequency': 1,
          'globalBW': 2,
          'subNetworkBW': 2,
          'routerBW': 2,
          'globalMaxDepth':8,
          'subNetworkMaxDepth':5,
          'routerMaxDepth': 5 }
        if configFile:
            #evaluate each key:=value pair and stick it into config
            with open(configFile, 'r') as f:
                for line in f:
                    if not line.startswith('#'):
                        r = line.split(':=')
                        bsConfig[r[0]] = ast.literal_eval(r[1])
        #set up probe schedule appropriately
        setProbeScheduleMsg = SetProbeSchedule.SetProbeSchedule(
          bsConfig['probeInterval'],
          [ bsConfig['globalChannel'], 
            bsConfig['subNetworkChannel'], 
            bsConfig['routerChannel']],
          [ bsConfig['globalInvFrequency'], 
            bsConfig['subNetworkInvFrequency'], 
            bsConfig['routerInvFrequency']],
          [ bsConfig['globalBW'], 
            bsConfig['subNetworkBW'], 
            bsConfig['routerBW']],
          [ bsConfig['globalMaxDepth'], 
            bsConfig['subNetworkMaxDepth'], 
            bsConfig['routerMaxDepth']])
        self.send(setProbeScheduleMsg, self.bsId, FALSE)
        time.sleep(1)

    #TODO: addListener should also:
    # * create a TunneledListener if one does not already exist
    # * add an entry in TunneledListener to unpack/convert/re-enqueue
    #   tunneled packets

    def addSource(self, s, isPrimary=True):
        '''There should be one primary source (e.g. serial connection
        to a basestation mote). This is where we will send all of the
        control messages. Additional sources can be added as in the
        original MoteIF, but all control messages will go to the
        primary. The send() function will send to the primary source
        unless specifically directed to do otherwise.'''
        if self.source and isPrimary:
            raise MultipleSourceException()
        else:
            s = MoteIF.addSource(self, s)
            if isPrimary:
                self.source = s
            return s

    def send(self, addr, msg, ackRequired=True, source=None):
        if not source:
            source = self.source
        error = 1
        retries = 0
        print "Sending"
        while error and retries <= self.retryLimit:
            print "send #", retries
            self.sendMsg(source, addr, msg.get_amType(), 0, msg)
            if not ackRequired:
                return
            try:
                m = self.ackQueue.get(True, self.sendTimeout)
                print "ack:", m
                if m:
                    error = m.get_error()
            except Queue.Empty:
                print "no ack"
                #no response before timeout
                pass
            finally:
                retries += 1

    def downloadWait(self):
        print "Waiting for download to finish"
        with self.finishedCV:
            self.finishedCV.wait()
