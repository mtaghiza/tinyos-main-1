#!/usr/bin/env python
from autoPush.decoders import Decoder
import sqlite3
import struct

class BaconSettings(Decoder.Decoder):
    @classmethod 
    def recordType(cls):
        return 0x17
    
    def unpack(self, source, cookie, data):
        ds = ''.join([chr(v) for v in data])
        header = ds[0:7]
        body = ds[7:]
        (rc, ts, offset) = struct.unpack('<HLB', header)
        return (source, cookie, rc, ts, offset, buffer(body))

    def insert(self, source, cookie, data):
        if not self.connected:
            self.connection = sqlite3.connect(self.dbName)
        q ='''INSERT OR IGNORE INTO bacon_settings 
           (node_id, cookie, rc, ts, offset, data) values 
           (?,       ?,      ?,  ?,  ?,      ?)'''
        t = self.unpack(source, cookie, data)
        print "Decoded Bacon Settings"
        self.connection.execute(q, t)
        self.connection.commit()

