#!/usr/bin/env python
from threading import Condition

class CxDownloadFinishedListener(object):
    def __init__(self):
        self.finishedCV = Condition()
        self.finished = False

    def receive(self, src, msg):
        print "FINISHED"
        with self.finishedCV:
            self.finished = True
            self.finishedCV.notify()
