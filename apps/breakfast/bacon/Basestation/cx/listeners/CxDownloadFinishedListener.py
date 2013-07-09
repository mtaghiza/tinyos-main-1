#!/usr/bin/env python

class CxDownloadFinishedListener(object):
    def __init__(self, finishedCV):
        self.finishedCV = finishedCV

    def receive(self, src, msg):
        print "FINISHED"
        with self.finishedCV:
            self.finishedCV.notify()
