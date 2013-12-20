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
        print "Status", msg
        q0 = ''' INSERT INTO base_reference
          (node1, rc1, ts1, unixTS) VALUES
          (?, ?, ?, ?)'''
        self.db.insert.execute(q0, 
          (msg.addr, msg.get_wakeupRC(), msg.get_wakeupTS(),
            self.downloadStart))
        q1 = '''INSERT INTO node_status 
          (node_id, ts, barcode_id, writeCookie, subnetChannel, sampleInterval, role) 
          VALUES (?, ?, ?, ?, ?, ?, ?)'''
        #TODO: format entire barcode correctly
        self.db.insert.execute(q1, (msg.addr, 
          time.time(),
          hex(msg.addr),
          msg.get_writeCookie(),
          msg.get_subnetChannel(), 
          msg.get_sampleInterval(),
          msg.get_role()))
        if self.refCallBack:
            self.refCallBack(msg.addr, neighbors, msg.get_pushCookie(),
                msg.get_writeCookie(), msg.get_missingLength())
