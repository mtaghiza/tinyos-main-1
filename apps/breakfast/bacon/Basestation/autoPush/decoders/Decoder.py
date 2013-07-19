#!/usr/bin/env python
def toHexArrayStr(data):
   return "[" + ', '.join([hex(v) for v in data])+ "]" 

class Decoder(object):
    def __init__(self, dbName):
        self.dbName = dbName
        self.connected = False
        pass

    def __del__(self):
        if self.connected == True:
            #self.cursor.close()
            self.connection.close()

    @classmethod
    def decode(self, arr, reverseByteOrder=True):
        if reverseByteOrder:
            return reduce(lambda l, r: (l<<8) + r, reversed(arr), 0)
        else:
            return reduce(lambda l, r: (l<<8) + r, arr, 0)

    @classmethod
    def recordType(cls):
        return None

    def insert(self, source, cookie, data):
        pass
