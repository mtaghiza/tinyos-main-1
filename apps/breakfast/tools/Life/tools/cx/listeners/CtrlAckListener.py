#!/usr/bin/env python

class CtrlAckListener(object):
    def __init__(self, ackQueue):
        self.ackQueue = ackQueue

    def receive(self, src, msg):
        print "ACK %u"%msg.get_error()
        self.ackQueue.put(msg)
