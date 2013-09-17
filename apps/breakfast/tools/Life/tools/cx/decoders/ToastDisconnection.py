#!/usr/bin/env python
from tools.cx.decoders import Decoder
import sqlite3
import struct

class ToastDisconnection(Decoder.Decoder):
    @classmethod 
    def recordType(cls):
        return 0x10

    def unpack(self, source, cookie, data):
        ds = ''.join([chr(v) for v in data])
        header = ds[0:6]
        toastIdS = ds[6:]
        (rc, ts) = struct.unpack('<HL', header)
        return (source, cookie, rc, ts, buffer(toastIdS))

    def insert(self, source, cookie, data):
        if not self.connected:
            self.connection = sqlite3.connect(self.dbName)
        q ='''INSERT OR IGNORE INTO toast_disconnection 
           (node_id, cookie, reboot_counter, time, toast_id) values 
           (?,       ?,      ?,              ?,    ?)'''

        (source, cookie, rc, ts, toastIdBin) = self.unpack(source, cookie, data)
        toastIdText = Decoder.toHexStr(toastIdBin)
        self.connection.execute(q, (source, cookie, rc, ts, toastIdText))
        self.connection.commit()
