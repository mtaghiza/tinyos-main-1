#!/usr/bin/env python
from threading import Condition

class FwdStatusListener(object):
    def __init__(self):
        self.cv = Condition()
        #before receiving first status report, assume you have space
        # for at least one packet
        self.spaceFree = 1

    def receive(self, src, msg):
        print "receive fwd status %u"%msg.get_queueCap()
        with self.cv:
            self.spaceFree = msg.get_queueCap()
            self.cv.notifyAll()

