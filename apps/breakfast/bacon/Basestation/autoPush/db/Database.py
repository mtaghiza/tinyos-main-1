#!/usr/bin/env python

import threading

from DatabaseInit import DatabaseInit
from DatabaseInsert import DatabaseInsert
from DatabaseMissing import DatabaseMissing


class Database(object):

    def __init__(self):
        init = DatabaseInit('database')
        dbName = init.getName()

        self.insert = DatabaseInsert(dbName)
        self.missing = DatabaseMissing(dbName)
        

    def insertRecord(self, source, record):
        #print "Database.insertRecord()", threading.current_thread().name
        
        (cookie, nextCookie, length, data) = record            
        
        print "Database.insertRecord()", source, cookie, nextCookie, length, data
        
        self.insert.insertFlash(source, cookie, nextCookie, length)        
        
            ##calcLen = cookieVal - self.oldCookieVal - 1
            ##print "# %X" % cookieVal, calcLen, self.oldLenVal
            ##if calcLen != self.oldLenVal:
            ##    print '============================================='
            ##
            ## print lenVal, recordData
            ##self.oldCookieVal = cookieVal
            ##self.oldLenVal = lenVal

    def findMissing(self):
        
        return self.missing.findMissing()
        


if __name__ == '__main__':

    db = Database()

    missing_list = db.findMissing()

    for rec in missing_list:
        print rec
    
    







