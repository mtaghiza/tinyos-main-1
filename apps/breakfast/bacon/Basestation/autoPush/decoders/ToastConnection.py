#!/usr/bin/env python
from autoPush.decoders import Decoder
import sqlite3
import struct

class ToastConnection(Decoder.Decoder):
    @classmethod 
    def recordType(cls):
        return 0x11
    
    def unpack(self, source, cookie, data):
        ds = ''.join([chr(v) for v in data])
        header = ds[0:6]
        body = ds[6:]
        (rc, ts) = struct.unpack('<HL', header)
        return (source, cookie, rc, ts, buffer(body))

    def insert(self, source, cookie, data):
        if not self.connected:
            self.connection = sqlite3.connect(self.dbName)
        q ='''INSERT OR IGNORE INTO toast_connection 
           (node_id, cookie, reboot_counter, time, toast_id, tlv) values 
           (?,       ?,      ?,              ?,    ?,       ?)'''
        q1='''INSERT OR IGNORE INTO sensor_connection 
           (node_id, cookie, channel_number, sensor_type, sensor_id) values 
           (?,       ?,      ?,  ?,  ?)'''

        (source, cookie, rc, ts, tlv) = self.unpack(source, cookie, data)
        print "Toast Connection raw:", [hex(c) for c in data]
        print "Toast Connection unpacked:", source, cookie, rc, ts, [hex(ord(c)) for c in tlv]
        for (tag, length, value) in Decoder.tlvIterator(tlv):
            print "next (t,l,v)", tag, length, [hex(ord(c)) for c in value]
            if tag == 0x05:
                i = 0
                channel = 0
                while i < length:
                    (sensorType, sensorId) = struct.unpack('<BH', value[i:i+3])
                    self.connection.execute(q1, (source, cookie, channel, sensorType, sensorId))
                    i += 3
                    channel += 1
            if tag == 0x04:
                toastIdBin = value
                toastIdText = Decoder.toHexStr(toastIdBin)
                self.connection.execute(q, (source, cookie, rc, ts, toastIdText, tlv))

        self.connection.commit()
