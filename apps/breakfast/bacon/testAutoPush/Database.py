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
        
        print source, cookie, nextCookie, length, data
        
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
    
    







