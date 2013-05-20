#!/usr/bin/env python

import sys

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
            
            recordData = self.data[index:index + lenVal]
            index += lenVal
            
            if prevLenVal != 0:
                recordList.append( (prevCookieVal, cookieVal, prevLenVal, prevRecordData) )

            if index == self.length:
                recordList.append( (cookieVal, self.nextCookie, lenVal, recordData) )               
             
            prevCookieVal = cookieVal
            prevRecordData = recordData
            prevLenVal = lenVal
            
            
            # panic
            if cookieVal > self.nextCookie or lenVal > 15:
                print cookieBytes
                print self.data 
                print self.nextCookie 
                print self.length 

            
            
        return recordList

    
    
    


