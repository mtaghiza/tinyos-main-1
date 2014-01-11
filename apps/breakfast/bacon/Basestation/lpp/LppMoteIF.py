#!/usr/bin/env python

# Copyright (c) 2014 Johns Hopkins University
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# - Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
# - Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the
#   distribution.
# - Neither the name of the copyright holders nor the names of
#   its contributors may be used to endorse or promote products derived
#   from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
# THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.


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
        #first, flush out anything that's kicking around in the queue.
        while self.queue.qsize():
            m = self.queue.get(False)
            if m.addr == addr:
                return m
        #if there's no data from this node left in the queue, then
        # send it a CTS and wait for a response
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
