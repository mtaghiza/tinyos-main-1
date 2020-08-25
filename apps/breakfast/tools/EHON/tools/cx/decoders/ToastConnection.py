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
            print "next (t,l,v)", hex(tag), length, ' '.join([hex(ord(c)) for c in value])
            if tag == 0x05:
                i = 0
                channel = 0
                while i < length:
                    (sensorType, sensorId) = struct.unpack('>BH', value[i:i+3])
                    self.dbInsert.execute(q1, (source, cookie, channel, sensorType, sensorId))
                    i += 3
                    channel += 1
            if tag == 0x04:
                toastIdBin = value
                toastIdText = Decoder.toHexStr(toastIdBin)
                self.dbInsert.execute(q, (source, cookie, rc, ts, toastIdText, tlv))
