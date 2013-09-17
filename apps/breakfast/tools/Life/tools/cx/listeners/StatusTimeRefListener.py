#!/usr/bin/env python
import time
import sqlite3

class StatusTimeRefListener(object):
    def __init__(self, dbName):
        self.downloadStart = None
        self.dbName = dbName

    def receive(self, src, msg):
        print "REF", self.downloadStart, msg.get_node(), msg.get_rc(), msg.get_ts()
        q = ''' INSERT INTO base_reference
          (node1, rc1, ts1, unixTS) VALUES
          (?,     ?,   ?,   ?)'''
        self.connection = sqlite3.connect(self.dbName)
        self.connection.execute(q, 
          (msg.get_node(), msg.get_rc(), msg.get_ts(), self.downloadStart))
        self.connection.commit()

