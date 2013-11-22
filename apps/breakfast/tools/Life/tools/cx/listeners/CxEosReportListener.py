#!/usr/bin/env python

class CxEosReportListener(object):
    def __init__(self, eosQueue):
        self.eosQueue = eosQueue

    def receive(self, src, msg):
        print "receive eos", msg
        self.eosQueue.put(msg)
