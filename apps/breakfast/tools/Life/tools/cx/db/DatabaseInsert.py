#!/usr/bin/env python

import sqlite3
import time
import threading

class DatabaseInsert(object):

    def __init__(self, dbName):
        self.dbName = dbName
        self.connected = False
        #print "DatabaseInsert()", threading.current_thread().name

    def connect(self):
        if not self.connected:
            self.connected = True
            self.connection = sqlite3.connect(self.dbName)
                
    def __del__(self):
        if self.connected:
            self.connection.commit()
            #self.cursor.close()
            self.connection.close()
            print "closing connection"
        
    def insertFlash(self, node_id, cookie, nextCookie, length):
        cookieDiff = nextCookie - (cookie + length)
        if (0 < length) and (length < 140) and (cookieDiff > 0) and (cookieDiff < 0xFF):
            # the table has a PK uniqueness constraint on (node_id, cookie)
            # duplicate data is ignored
            row = [node_id, time.time(), cookie, nextCookie, length]
            self.execute('INSERT OR IGNORE INTO cookie_table (node_id, base_time, cookie, nextCookie, length) VALUES (?,?,?,?,?)', row)        

    def commit(self):
        self.connect()
        self.connection.commit()
    
    def insertRaw(self, source, message):
        self.execute('INSERT INTO packet (src, ts, amId, data) values (?, ?, ?, ?)',
            (message.addr, 
              time.time(), 
              message.am_type,
              sqlite3.Binary(bytearray(message.data))))

    def execute(self, query, args):
        self.connect()
        self.connection.execute(query, args)
