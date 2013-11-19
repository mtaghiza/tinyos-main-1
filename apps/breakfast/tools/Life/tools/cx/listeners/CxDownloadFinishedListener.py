#!/usr/bin/env python

class CxDownloadFinishedListener(object):
    def __init__(self):
        self.finished = False

    def receive(self, src, msg):
        print "FINISHED"
        self.finished = True
