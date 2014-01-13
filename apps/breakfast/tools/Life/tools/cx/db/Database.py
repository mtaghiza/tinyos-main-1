#!/usr/bin/env python

# Copyright (c) 2014 Johns Hopkins University
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# - Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
# - Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the
#   distribution.
# - Neither the name of the copyright holders nor the names of
#   its contributors may be used to endorse or promote products derived
#   from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
# THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.


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

    def allNodeMissing(self, node, incrementRetries=True):
        return self.missing.allNodeMissing(node, incrementRetries)
    
    def stop(self):
        self.insert.stop()


if __name__ == '__main__':

    db = Database()

    missing_list = db.findMissing()

    for rec in missing_list:
        print rec
    
    







