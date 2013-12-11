#!/usr/bin/env python

import threading

from DatabaseInsert import DatabaseInsert
from DatabaseMissing import DatabaseMissing

import time
from threading import Thread


class Database(object):

    def __init__(self, dbName):
        self.dbName = dbName

        self.insert = DatabaseInsert(self.dbName)

        self.insertThread = Thread(target=self.insert.mainLoop,
          name="dbInsert")
        self.insertThread.start()
        self.missing = DatabaseMissing(self.dbName)
        self.decoders = {}
        

    def addDecoder(self, decoderClass):
        self.decoders[decoderClass.recordType()] = decoderClass(self.insert)
        return self.decoders[decoderClass.recordType()]


    def insertRecord(self, source, record):
        #print "Database.insertRecord()", threading.current_thread().name
        
        (cookie, nextCookie, length, recordType, data) = record            
        
        print "Database.insertRecord()", source, cookie, nextCookie, length, recordType, data
        
        self.insert.insertFlash(source, cookie, nextCookie, length)        
        if recordType in self.decoders:
            self.decoders[recordType].insert(source, cookie, data)

            ##calcLen = cookieVal - self.oldCookieVal - 1
            ##print "# %X" % cookieVal, calcLen, self.oldLenVal
            ##if calcLen != self.oldLenVal:
            ##    print '============================================='
            ##
            ## print lenVal, recordData
            ##self.oldCookieVal = cookieVal
            ##self.oldLenVal = lenVal
        else: 
            print "No decoder for 0x%x"%recordType

    def insertRaw(self, source, message):
        self.insert.insertRaw(source, message)
#         print "RAW",message.addr, time.time(), message.am_type, message.data

    def findMissing(self, incrementRetries=True):
        return self.missing.findMissing(incrementRetries)

    def nodeMissing(self, node, incrementRetries=True):
        return self.missing.nodeMissing(node, incrementRetries)
    
    def stop(self):
        self.insert.stop()


if __name__ == '__main__':

    db = Database()

    missing_list = db.findMissing()

    for rec in missing_list:
        print rec
    
    







