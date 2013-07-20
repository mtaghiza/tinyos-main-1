#!/usr/bin/env python
import time

class StatusTimeRefListener(object):
    def __init__(self):
        self.downloadStart = None
        pass

    def receive(self, src, msg):
        print "REF", self.downloadStart, msg.get_node(), msg.get_rc(), msg.get_ts()
        #TODO: hand off query/params to db thread
