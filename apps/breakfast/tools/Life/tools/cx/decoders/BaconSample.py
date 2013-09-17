#!/usr/bin/env python
from tools.cx.decoders import Decoder
import sqlite3

class BaconSample(Decoder.Decoder):
    @classmethod 
    def recordType(cls):
        return 0x14

    def unpack(self, source, cookie, data):
        rc = self.decode(data[0:2])
        baseTime = self.decode(data[2:6])
        battery = self.decode(data[6:8])
        light = self.decode(data[8:10])
        thermistor = self.decode(data[10:12])
        return (source, cookie, rc, baseTime, battery, light, thermistor)

    def insert(self, source, cookie, data):
        if not self.connected:
            self.connection = sqlite3.connect(self.dbName)
        q='''INSERT OR IGNORE INTO bacon_sample 
             (node_id, cookie, reboot_counter, base_time, battery, light, thermistor) 
             VALUES (?, ?, ?, ?, ?, ?, ?)'''
        t = self.unpack(source, cookie, data)
        print "Decoded Bacon Sample", Decoder.toHexArrayStr(data), "to", Decoder.toHexArrayStr(t)
        self.connection.execute(q, t)
        self.connection.commit()
