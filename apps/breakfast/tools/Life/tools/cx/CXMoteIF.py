#!/usr/bin/env python
from tinyos.message.MoteIF import MoteIF
import Queue 
import time
import ast


from tools.cx.listeners.CtrlAckListener import CtrlAckListener
from tools.cx.messages.CtrlAck import CtrlAck

from tools.cx.listeners.CxDownloadFinishedListener import CxDownloadFinishedListener
from tools.cx.messages.CxDownloadFinished import CxDownloadFinished
from tools.cx.messages import SetProbeSchedule
from tools.cx.messages import SetMaxDownloadRounds

class MultipleSourceException(Exception):
    pass

class CXMoteIF(MoteIF):
    def __init__(self, bsId):
        MoteIF.__init__(self)
        self.ackQueue = Queue.Queue()
        self.addListener(CtrlAckListener(self.ackQueue),
          CtrlAck)
        self.finishedListener = CxDownloadFinishedListener()
        self.addListener(self.finishedListener, CxDownloadFinished)
        #TODO: less arbitrary. In fact, we should probably be waiting
        # until we get a downloadFinished. Might be helpful to add 
        # downloadOngoing / haltDownload packets?
        self.sendTimeout = 30
        self.retryLimit = 0
        self.source = None
        self.bsId = bsId

    def configureMoteRadio(self, moteId, configFile):
        #sensible defaults
        radioConfig = {
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
          'routerMaxDepth': 5,
          'maxDownloadRounds':10}
        if configFile:
            #evaluate each key:=value pair and stick it into config
            with open(configFile, 'r') as f:
                for line in f:
                    if not line.startswith('#'):
                        r = line.split(':=')
                        radioConfig[r[0]] = ast.literal_eval(r[1])
        #set up probe schedule appropriately
        setProbeScheduleMsg = SetProbeSchedule.SetProbeSchedule(
          radioConfig['probeInterval'],
          [ radioConfig['globalChannel'], 
            radioConfig['subNetworkChannel'], 
            radioConfig['routerChannel']],
          [ radioConfig['globalInvFrequency'], 
            radioConfig['subNetworkInvFrequency'], 
            radioConfig['routerInvFrequency']],
          [ radioConfig['globalBW'], 
            radioConfig['subNetworkBW'], 
            radioConfig['routerBW']],
          [ radioConfig['globalMaxDepth'], 
            radioConfig['subNetworkMaxDepth'], 
            radioConfig['routerMaxDepth']])
        ackExpected = ( moteId != self.bsId)
        self.send(moteId, setProbeScheduleMsg, ackExpected)

    def configureMaxDownloadRounds(self, moteId, configFile):
        radioConfig = { 'maxDownloadRounds':10}
        if configFile:
            #evaluate each key:=value pair and stick it into config
            with open(configFile, 'r') as f:
                for line in f:
                    if not line.startswith('#'):
                        r = line.split(':=')
                        radioConfig[r[0]] = ast.literal_eval(r[1])
        setMaxDownloadRoundsMsg = SetMaxDownloadRounds.SetMaxDownloadRounds(
          radioConfig['maxDownloadRounds']
          )
        self.send(moteId, setMaxDownloadRoundsMsg, False)

        time.sleep(1)


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
        print "Sending", msg, "to", addr
        while error and retries <= self.retryLimit:
            self.sendMsg(source, addr, msg.get_amType(), 0, msg)
            if not ackRequired:
                print "(no ack required)"
                return 0
            try:
                m = self.ackQueue.get(True, self.sendTimeout)
                print "ack:", m
                if m:
                    error = m.get_error()
            except Queue.Empty:
                print "no ack received"
                #no response before timeout
                pass
            finally:
                retries += 1
        return error

    def downloadWait(self):
        print "Waiting for download to finish"
        while not self.finishedListener.finished:
            with self.finishedListener.finishedCV:
                self.finishedListener.finishedCV.wait()

    def clearRXQueue(self):
        print "Clearing RX Queue"
        while not self.receiveQueue.empty():
            time.sleep(1)
            print "Still waiting for queue to clear"
        print "QUEUE CLEARED"
