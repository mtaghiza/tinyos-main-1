#!/usr/bin/env python
def toHexArrayStr(data):
   return "[" + ', '.join([hex(v) for v in data])+ "]" 

def toHexStr(dataBin, reverseByteOrder = True):
    if reverseByteOrder:
        arr = reversed(dataBin)
    else:
        arr = dataBin
    return '0x'+''.join(['%02x'%ord(c) for c in arr])
        

def tlvIterator(data):
    #skip CRC
    i = 2
    while i < len(data):
        #format:
        # tag, len, [b x len]
        tag = ord(data[i])
        l = ord(data[i+1])
        d = data[i+2:i+2+l]
        yield (tag, l, d)
        i += l+2

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
