#!/usr/bin/env python
import time

class StatusTimeRefListener(object):
    def __init__(self):
        pass

    def receive(self, src, msg):
        print "REF", time.time(), msg.get_node(), msg.get_rc(), msg.get_ts()
