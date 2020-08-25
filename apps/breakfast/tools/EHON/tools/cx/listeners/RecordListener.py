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


class RecordParser(object):
    COOKIE_LEN = 4
    LENGTH_LEN = 1
    
    def __init__(self, recordMsg):
        self.data = recordMsg.get_data()
        self.nextCookie = recordMsg.get_nextCookie()
        self.length = recordMsg.get_length()
 
    def val(self, arr):
        return reduce(lambda l, r: (l<<8) + r, arr, 0)

    def getList(self):   
        index = 0
        recordList = []
        prevCookieVal = 0
        prevRecordData = 0
        prevLenVal = 0
        
        while index < self.length:
            cookieBytes = self.data[index:index+RecordParser.COOKIE_LEN]
            cookieVal = self.val(cookieBytes)
            index += RecordParser.COOKIE_LEN
            
            lenVal = self.val(self.data[index:index+RecordParser.LENGTH_LEN])
            index += RecordParser.LENGTH_LEN
            
            recordType = self.data[index]
            recordData = self.data[index+1:index + lenVal]
            index += lenVal
            
            if prevLenVal != 0:
                recordList.append( (prevCookieVal, cookieVal, prevLenVal, prevRecordType, prevRecordData) )

            if index == self.length:
                recordList.append( (cookieVal, self.nextCookie, lenVal, recordType, recordData) )               
             
            prevCookieVal = cookieVal
            prevRecordType = recordType
            prevRecordData = recordData
            prevLenVal = lenVal
            
            # panic
            if cookieVal > self.nextCookie:
                print "I am panicking: %u > %u"%(cookieVal,
                  self.nextCookie)
                print cookieBytes
                print self.data 
                print self.nextCookie 
                print self.length 

        return recordList

class RecordListener(object):
    def __init__(self, db):
        self.db = db

    def receive(self, src, msg):
        #TODO: this should be in a generic message-listener
        self.db.insertRaw(src, msg)
        address = msg.getAddr()
        rp = RecordParser(msg)        
        records = rp.getList()
        print "RPR rx from %u len %u nc %u records %u"%(address, rp.length, rp.nextCookie, len(records))
        for rec in records:
            self.db.insertRecord(address, rec)
