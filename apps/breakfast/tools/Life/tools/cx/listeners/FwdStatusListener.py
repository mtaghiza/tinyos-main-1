#!/usr/bin/env python

class FwdStatusListener(object):
    def __init__(self, fwdStatusQueue):
        self.fwdStatusQueue = fwdStatusQueue

    def receive(self, src, msg):
        print "receive fwd status %u"%msg.get_queueCap()
        self.fwdStatusQueue.put(msg)

