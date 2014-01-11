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
        q0='''INSERT OR IGNORE INTO toast_sample 
             (node_id, cookie, reboot_counter, base_time, toast_id) VALUES 
             (?,       ?,      ?,              ?,         ?)'''
        q1='''INSERT OR IGNORE INTO sensor_sample 
             (node_id, cookie, channel_number, sample) VALUES 
             (?,       ?,      ?,              ?)'''
        (rc, ts, samplerIdBin, samples) = self.unpack(data)
        samplerIdText = Decoder.toHexStr(samplerIdBin)
        self.dbInsert.execute(q0, (source, cookie, rc, ts, samplerIdText))
        for (channel, sample) in enumerate(samples):
            self.dbInsert.execute(q1, (source, cookie, channel, sample))
