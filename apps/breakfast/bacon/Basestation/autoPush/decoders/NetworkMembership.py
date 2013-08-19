#!/usr/bin/env python
from autoPush.decoders import Decoder
import sqlite3
import struct

class NetworkMembership(Decoder.Decoder):
    @classmethod 
    def recordType(cls):
        return 0x19

    def unpack(self, source, cookie, data):
        ds = ''.join([chr(v) for v in data])
        header = ds[0:10]
        (masterId, networkSegment, channel, rc, ts) = struct.unpack('>HBBHL', header)
        numMembers = 25
        memberData = ds[10:10+(numMembers*2)]
        distanceData = ds[10+(numMembers*2):]
        members = struct.unpack('>'+numMembers*'H', memberData)
        distances = struct.unpack('>'+numMembers*'B', distanceData)
        memberDistances = zip(members, distances)
        return (source, cookie, masterId, networkSegment, channel, rc, ts, memberDistances)

    def insert(self, source, cookie, data):
        if not self.connected:
            self.connection = sqlite3.connect(self.dbName)
        (source, cookie, masterId, networkSegment, channel, rc, ts, memberDistances) = self.unpack(source, cookie, data)
        q0 = '''INSERT INTO active_period (master_id, cookie, rc, ts, network_segment, channel) VALUES (?, ?, ?, ?, ?, ?)'''
        q1 = '''INSERT INTO network_membership (master_id, cookie, slave_id, distance) VALUES (?, ?, ?, ?)'''
        self.connection.execute(q0, 
          (masterId, cookie, rc, ts, networkSegment, channel))
        for (member, distance) in memberDistances:
            if member != 0xFFFF:
                self.connection.execute(q1,
                  (masterId, cookie, member, distance))

        self.connection.commit()
