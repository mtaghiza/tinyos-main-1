#!/usr/bin/env python

# Copyright (c) 2014 Johns Hopkins University
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# - Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
# - Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the
#   distribution.
# - Neither the name of the copyright holders nor the names of
#   its contributors may be used to endorse or promote products derived
#   from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
# THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.

from tools.cx.decoders import Decoder
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
        (source, cookie, masterId, networkSegment, channel, rc, ts, memberDistances) = self.unpack(source, cookie, data)
        q0 = '''INSERT INTO active_period (master_id, cookie, rc, ts, network_segment, channel) VALUES (?, ?, ?, ?, ?, ?)'''
        q1 = '''INSERT INTO network_membership (master_id, cookie, slave_id, distance) VALUES (?, ?, ?, ?)'''
        self.dbInsert.execute(q0, 
          (masterId, cookie, rc, ts, networkSegment, channel))
        for (member, distance) in memberDistances:
            if member != 0xFFFF:
                self.dbInsert.execute(q1,
                  (masterId, cookie, member, distance))
