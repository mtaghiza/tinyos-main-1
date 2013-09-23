#!/usr/bin/env python

import sqlite3
import time
import threading

class DatabaseInsert(object):

    def __init__(self, dbName):
        self.dbName = dbName
        self.connected = False
        #print "DatabaseInsert()", threading.current_thread().name

                
    def __del__(self):
        if self.connected == True:
            #self.cursor.close()
            self.connection.close()
            
            print "closing connection"
        
    def insertFlash(self, node_id, cookie, nextCookie, length):
             
        cookieDiff = nextCookie - (cookie + length)
        
        if (0 < length) and (length < 140) and (cookieDiff > 0) and (cookieDiff < 0xFF):
            
            # sqlite connections can only be used from the same threads they are established from
            if self.connected == False:
                self.connected == True
                # raises sqlite3 exceptions
                self.connection = sqlite3.connect(self.dbName)
                #self.cursor = self.connection.cursor()

            # the table has a PK uniqueness constraint on (node_id, cookie)
            # duplicate data is ignored
            row = [node_id, time.time(), cookie, nextCookie, length]
            self.connection.execute('INSERT OR IGNORE INTO cookie_table (node_id, base_time, cookie, nextCookie, length) VALUES (?,?,?,?,?)', row)        
            self.connection.commit();
            
        #print "DatabaseInsert.insertFlash()", threading.current_thread().name
    
    def insertRaw(self, source, message):
        if self.connected == False:
            self.connected == True
            # raises sqlite3 exceptions
            self.connection = sqlite3.connect(self.dbName)
            #self.cursor = self.connection.cursor()
        self.connection.execute('INSERT INTO packet (src, ts, amId, data) values (?, ?, ?, ?)',
            (message.addr, 
              time.time(), 
              message.am_type,
              sqlite3.Binary(bytearray(message.data))))
        self.connection.commit()
