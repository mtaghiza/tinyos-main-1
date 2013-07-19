#!/usr/bin/env python
from autoPush.decoders import Decoder
import sqlite3
import struct

class Phoenix(Decoder.Decoder):
    @classmethod 
    def recordType(cls):
        return 0x16
    
    def unpack(self, source, cookie, data):
        ds = ''.join([chr(v) for v in data])
        (node2, rc1, rc2, localTime1, localTime2) = struct.unpack('<HHHLL', ds)
        return (source, cookie, node2, rc1, rc2, localTime1, localTime2)

    def insert(self, source, cookie, data):
        if not self.connected:
            self.connection = sqlite3.connect(self.dbName)
        q='''INSERT OR IGNORE INTO phoenix_reference 
             (node1, cookie, node2, rc1, rc2, ts1, ts2) 
             VALUES (?, ?, ?, ?, ?, ?, ?)'''
        t = self.unpack(source, cookie, data)
        print "Decoded Phoenix Ref", Decoder.toHexArrayStr(data), "to", Decoder.toHexArrayStr(t)
        self.connection.execute(q, t)
        self.connection.commit()
