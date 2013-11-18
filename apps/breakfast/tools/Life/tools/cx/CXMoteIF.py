#!/usr/bin/env python
from tinyos.message.MoteIF import MoteIF
import Queue 
import time

from tools.labeler.TOS import TOS
from tools.cx.listeners.CtrlAckListener import CtrlAckListener
from tools.cx.messages.CtrlAck import CtrlAck

from tools.cx.listeners.CxDownloadFinishedListener import CxDownloadFinishedListener
from tools.cx.listeners.IdentifyResponseListener import IdentifyResponseListener
from tools.cx.messages.FwdStatus import FwdStatus
from tools.cx.listeners.FwdStatusListener import FwdStatusListener
from tools.cx.messages.IdentifyResponse import IdentifyResponse
from tools.cx.messages.IdentifyRequest import IdentifyRequest
from tools.cx.messages.CxDownloadFinished import CxDownloadFinished
from tools.cx.messages import SetProbeSchedule
from tools.cx.messages import SetMaxDownloadRounds
from tools.cx.messages import CxDownload

import tools.cx.constants as constants

class MultipleSourceException(Exception):
    pass

class CXMoteIF(MoteIF):
    def __init__(self):
        MoteIF.__init__(self)
        self.ackQueue = Queue.Queue()
        self.addListener(CtrlAckListener(self.ackQueue),
          CtrlAck)
        self.fwdStatusQueue = Queue.Queue()
        self.addListener(FwdStatusListener(self.fwdStatusQueue),
          FwdStatus)
        self.finishedListener = CxDownloadFinishedListener()
        self.addListener(self.finishedListener, CxDownloadFinished)

        self.identifyResponseListener = IdentifyResponseListener()
        self.addListener(self.identifyResponseListener,
          IdentifyResponse)

        self.fwdStatusTimeout = 60
        self.source = None

    def identifyMote(self):
        identifyRequestMsg = IdentifyRequest()
        with self.identifyResponseListener.identifiedCV:
            self.sendMsg(self.source, 
              constants.BCAST_ADDR,
              identifyRequestMsg.get_amType(),
              0,
              identifyRequestMsg)
            self.identifyResponseListener.identifiedCV.wait(1)
        self.bsId = self.identifyResponseListener.moteId
        return self.bsId != constants.BCAST_ADDR
        

    def configureMoteRadio(self, moteId, config):
        radioConfig = constants.DEFAULT_RADIO_CONFIG.copy()
        radioConfig.update(config)
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

        #To base station: no queueing
        if moteId == self.bsId:
            self.sendMsg(self.source,
              moteId, 
              setProbeScheduleMsg.get_amType(),
              0,
              setProbeScheduleMsg)
        #To others, must be queue-aware
        else:
            self.send(moteId, setProbeScheduleMsg)

    def configureMaxDownloadRounds(self, moteId, config):
        radioConfig = constants.DEFAULT_RADIO_CONFIG.copy()
        radioConfig.update(config)
        setMaxDownloadRoundsMsg = SetMaxDownloadRounds.SetMaxDownloadRounds(
          radioConfig['maxDownloadRounds']
          )
        if moteId == self.bsId:
            self.sendMsg(self.source,
              moteId, 
              setMaxDownloadRoundsMsg.get_amType(),
              0,
              setMaxDownloadRoundsMsg)
        else:
            self.send(moteId, setMaxDownloadRoundsMsg)

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

    def downloadStart(self, bsId, networkSegment, source=None):
        if not source:
            source = self.source
        downloadMsg = CxDownload.CxDownload()
        downloadMsg.set_networkSegment(networkSegment)
        t0 = time.time() 
        error = self.sendMsg(source, bsId, 
          downloadMsg.get_amType(), 0, downloadMsg)
        #return the unix time that the download command was sent
        return (time.time() + t0)/2
        
    def send(self, addr, msg, source=None):
        if addr == self.bsId:
            print "Attempting remote send to base station?"
            return TOS.EINVAL
        if not source:
            source = self.source
        queueCap = 0
        retries = 0
        print "Sending", msg, "to", addr
        self.sendMsg(source, addr, msg.get_amType(), 0, msg)
        while not queueCap:
            try:
                m = self.fwdStatusQueue.get(True,
                  self.fwdStatusTimeout)
                print "dequeue fwd status", m
                if m:
                    queueCap = m.get_queueCap()
            except Queue.Empty:
                print "No fwd status received"
                return TOS.ENOACK
        return TOS.SUCCESS

    #TODO: replace downloadWait with eosWait 
    # - This should return either a download-finished or a status
    #   report on the node whose slot just ended

    def downloadWait(self):
        print "Waiting for download to finish"
        while not self.finishedListener.finished:
            with self.finishedListener.finishedCV:
                self.finishedListener.finishedCV.wait()

    def clearRXQueue(self):
        time.sleep(1)
        print "Clearing RX Queue"
        while not self.receiveQueue.empty():
            time.sleep(1)
            print "Still waiting for queue to clear"
        print "QUEUE CLEARED"
