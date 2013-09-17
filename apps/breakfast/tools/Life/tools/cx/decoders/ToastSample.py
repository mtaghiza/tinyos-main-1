#!/usr/bin/env python
from tools.cx.decoders import Decoder
import sqlite3
import struct

class ToastSample(Decoder.Decoder):
    @classmethod 
    def recordType(cls):
        return 0x12

    def unpack(self, data):
        ds = ''.join([chr(v) for v in data])
        header = ds[0:14]
        sampleStr = ds[14:]
        (rc, ts, samplerId) = struct.unpack('<HL8s', header)
        numChannels = len(sampleStr)/2
        unpackStr = '<'+'H'*numChannels
        samples = struct.unpack(unpackStr, sampleStr)
        return (rc, ts, samplerId, samples)

    def insert(self, source, cookie, data):
        if not self.connected:
            self.connection = sqlite3.connect(self.dbName)
        q0='''INSERT OR IGNORE INTO toast_sample 
             (node_id, cookie, reboot_counter, base_time, toast_id) VALUES 
             (?,       ?,      ?,              ?,         ?)'''
        q1='''INSERT OR IGNORE INTO sensor_sample 
             (node_id, cookie, channel_number, sample) VALUES 
             (?,       ?,      ?,              ?)'''
        (rc, ts, samplerIdBin, samples) = self.unpack(data)
        samplerIdText = Decoder.toHexStr(samplerIdBin)
        self.connection.execute(q0, (source, cookie, rc, ts, samplerIdText))
        for (channel, sample) in enumerate(samples):
            self.connection.execute(q1, (source, cookie, channel, sample))
        self.connection.commit()
