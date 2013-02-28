#!/usr/bin/env python

class RecordIterator(object):
    COOKIE_LEN = 4
    LENGTH_LEN = 1
    
    def val(self, arr):
        return reduce(lambda l, r: (l<<8) + r, arr, 0)

    def __init__(self, recordMsg):
        self.data = recordMsg.get_data()
        self.si = 0

    def __iter__(self):
        return self

    def next(self):
        while self.si < len(self.data):
            cookieBytes = self.data[self.si:self.si+RecordIterator.COOKIE_LEN]
            self.si += RecordIterator.COOKIE_LEN
            if cookieBytes == [0xff, 0xff, 0xff, 0xff]:
                raise StopIteration
            cookieVal = self.val(cookieBytes)
            lenVal = self.val(self.data[self.si:self.si+RecordIterator.LENGTH_LEN])
            self.si += RecordIterator.LENGTH_LEN
            recordData = self.data[self.si:self.si + lenVal]
            self.si += lenVal
            return (cookieVal, lenVal, recordData)
        raise StopIteration


