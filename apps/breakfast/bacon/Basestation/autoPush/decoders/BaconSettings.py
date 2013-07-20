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
        (node_id, cookie, rc, ts, offset, tlv) = t
        print "Decoded Bacon Settings"
        self.connection.execute(q, t)
        #if this is the second half, join em up
        if offset == 64:
            pass
            chunks = self.connection.execute('''select data from
            bacon_settings 
            WHERE node_id = ? and rc=? and ts=? 
            ORDER BY offset''', 
            (node_id, rc, ts)).fetchall()
            print chunks
            if (len(chunks) == 2):
                tlv = reduce(lambda l,r: l[0]+r[0], chunks)
                for (tag, length, value) in Decoder.tlvIterator(tlv):
                    if tag == 0x04:
                        baconID = buffer(value)
                        self.connection.execute('''INSERT OR IGNORE INTO bacon_id
                          (node_id, cookie, barcode_id) values
                          (?      , ?     , ?)''', 
                          (node_id, cookie, baconID))

        self.connection.commit()
        self.connection.close()

