#!/usr/bin/env python
from threading import Condition
import tools.cx.constants as constants

class IdentifyResponseListener(object):
    def __init__(self):
        self.identifiedCV = Condition()
        self.moteId = constants.BCAST_ADDR 

    def receive(self, src, msg):
        with self.identifiedCV:
            self.moteId = msg.addr
            self.identifiedCV.notify()
