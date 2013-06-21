#!/usr/bin/env python

from tinyos.message.MoteIF import MoteIF
import Queue 
import time

import CxLppWakeup
import CxLppCts
import CxLppSleep

DEFAULT_READ_TIMEOUT=1.0
AM_PRINTF_MSG=100

class LppListener(object):
    def __init__(self, wrapped, queue):
        self.wrapped = wrapped
        self.queue = queue

    def receive(self, src, msg):
        if msg.get_amType() != AM_PRINTF_MSG:
            self.queue.put(msg)
        self.wrapped.receive(src, msg)

class MultipleSourceException(Exception):
    pass

class LppMoteIF(MoteIF):
    def __init__(self):
        MoteIF.__init__(self)
        self.queue = Queue.Queue()
        self.source  = None

    def addListener(self, listener, msgClass):
        l = LppListener(listener, self.queue)
        MoteIF.addListener(self, l, msgClass)

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
        self.sendMsg(source, addr, msg.get_amType(), 0, msg)
        

    def readFrom(self, addr, timeout=DEFAULT_READ_TIMEOUT):
        cts = CxLppCts.CxLppCts()
        cts.set_addr(addr)
        self.send(addr, cts)
        try:
            if timeout:
                return self.queue.get(True, timeout).addr == addr
            else:
                return self.queue.get(False).addr == addr
        except Queue.Empty:
            return None

    def wakeup(self, bsId, duration=0, timeout=10):
        wakeup = CxLppWakeup.CxLppWakeup()
        wakeup.set_timeout(int(timeout*1024))
        wakeupDone = time.time() + duration
        self.send(bsId, wakeup)
        while time.time() < wakeupDone:
            time.sleep(1)
            self.send(bsId, wakeup)
    
    def sleep(self, bsId, delay=0):
        s = CxLppSleep.CxLppSleep()
        s.set_delay(delay)
        self.send(bsId, s)
