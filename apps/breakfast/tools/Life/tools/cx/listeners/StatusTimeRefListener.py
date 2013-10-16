#!/usr/bin/env python
import time
import sqlite3
import tools.cx.constants as constants

class StatusTimeRefListener(object):
    def __init__(self, db, refCallBack=None):
        self.downloadStart = None
        self.db = db
        self.refCallBack = refCallBack

    def receive(self, src, msg):
        neighbors = [v for v in msg.get_neighbors() if v != constants.BCAST_ADDR]
        print "REF", self.downloadStart, msg.addr, msg.get_wakeupRC(), msg.get_wakeupTS(), msg.get_dataPending(), neighbors
        q = ''' INSERT INTO base_reference
          (node1, rc1, ts1, unixTS) VALUES
          (?,     ?,   ?,   ?)'''
        self.db.insert.execute(q, 
          (msg.addr, msg.get_wakeupRC(), msg.get_wakeupTS(), self.downloadStart))
        if self.refCallBack:
            self.refCallBack(msg.addr, neighbors)
