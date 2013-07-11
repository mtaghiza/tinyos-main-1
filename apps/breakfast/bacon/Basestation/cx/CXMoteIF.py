#!/usr/bin/env python
from tinyos.message.MoteIF import MoteIF
import Queue 
import time

from threading import Condition

from cx.listeners.CtrlAckListener import CtrlAckListener
from cx.messages.CtrlAck import CtrlAck

from cx.listeners.CxDownloadFinishedListener import CxDownloadFinishedListener
from cx.messages.CxDownloadFinished import CxDownloadFinished

class MultipleSourceException(Exception):
    pass

class CXMoteIF(MoteIF):
    def __init__(self):
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

    def send(self, addr, msg, source=None):
        if not source:
            source = self.source
        error = 1
        retries = 0
        print "Sending"
        while error and retries <= self.retryLimit:
            print "send #", retries
            self.sendMsg(source, addr, msg.get_amType(), 0, msg)
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
