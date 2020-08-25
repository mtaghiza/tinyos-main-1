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
import tools.cx.constants

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
        q ='''INSERT OR IGNORE INTO bacon_settings 
           (node_id, cookie, rc, ts, offset, data, barcode_id, bacon_interval, toast_interval) values 
           (?,       ?,      ?,  ?,  ?,      ?,    '',         ?,              ?)'''
        t = self.unpack(source, cookie, data)
        (node_id, cookie, rc, ts, offset, tlv ) = t
        print "Decoded Bacon Settings"
        self.dbInsert.execute(q, 
          (node_id, cookie, rc, ts, offset, tlv, 
           tools.cx.constants.DEFAULT_SAMPLE_INTERVAL,
           tools.cx.constants.DEFAULT_SAMPLE_INTERVAL))
        #if this is the second half, join em up
        if offset == 64:
            pass
            chunks = self.dbInsert.executeNow('''select data from
            bacon_settings 
            WHERE node_id = ? and rc=? and ts=? 
            ORDER BY offset''', 
            (node_id, rc, ts))
#             print chunks
            if (len(chunks) == 2):
                tlv = reduce(lambda l,r: l[0]+r[0], chunks)
                for (tag, length, value) in Decoder.tlvIterator(tlv):
                    print "next (t,l,v)", hex(tag), length, ' '.join([hex(ord(c)) for c in value])
                    if tag == tools.cx.constants.SS_KEY_GLOBAL_ID:
                        baconIDText = Decoder.toHexStr(buffer(value))
                        self.dbInsert.execute('''UPDATE
                        bacon_settings SET barcode_id = ? WHERE
                        node_id=? and rc = ? and ts=?''',
                          (baconIDText, node_id, rc, ts))
                    if tag == tools.cx.constants.SS_KEY_BACON_SAMPLE_INTERVAL:
                        (baconSampleInterval,) = struct.unpack('>L', value)
                        self.dbInsert.execute('''UPDATE bacon_settings
                        SET bacon_interval = ? 
                        WHERE node_id=? and rc=? and ts=?''',
                        (baconSampleInterval, node_id, rc, ts))
                    if tag == tools.cx.constants.SS_KEY_TOAST_SAMPLE_INTERVAL:
                        (toastSampleInterval,) = struct.unpack('>L', value)
                        self.dbInsert.execute('''UPDATE bacon_settings
                        SET toast_interval = ? 
                        WHERE node_id=? and rc=? and ts=?''',
                        (toastSampleInterval, node_id, rc, ts))
                    if tag == tools.cx.constants.SS_KEY_LOW_PUSH_THRESHOLD:
                        (lpt,) = struct.unpack('>B', value)
                        self.dbInsert.execute(
                          '''UPDATE bacon_settings 
                          SET low_push_threshold=?
                          WHERE node_id=? and rc=? and ts=?''',
                          (lpt, node_id, rc, ts))
                    if tag == tools.cx.constants.SS_KEY_HIGH_PUSH_THRESHOLD:
                        (hpt,) = struct.unpack('>B', value)
                        self.dbInsert.execute(
                          '''UPDATE bacon_settings 
                          SET high_push_threshold=?
                          WHERE node_id=? and rc=? and ts=?''',
                          (hpt, node_id, rc, ts))
                    if tag == tools.cx.constants.SS_KEY_PROBE_SCHEDULE:
                        (probeInterval, 
                         globalChannel, subnetChannel, routerChannel, 
                         globalIf, subnetIf, routerIf,
                         globalBW, subnetBW, routerBW, 
                         globalMD, subnetMD, routerMD,
                         globalWUL, subnetWUL, routerWUL) = struct.unpack('>LBBBBBBBBBBBBLLL', value)
                        self.dbInsert.execute(
                          '''UPDATE bacon_settings 
                          SET probe_interval =?, 
                          global_channel=?, subnetwork_channel=?, router_channel=?,
                          global_inv_freq=?, subnetwork_inv_freq=?, router_inv_freq=?,
                          global_bw=?, subnetwork_bw=?, router_bw=?,
                          global_md=?, subnetwork_md=?, router_md=?,
                          global_wul=?, subnetwork_wul=?, router_wul=?
                          WHERE node_id=? and rc=? and ts=?''',
                          (probeInterval,
                          globalChannel, subnetChannel, routerChannel,
                          globalIf, subnetIf, routerIf,
                          globalBW, subnetBW, routerBW,
                          globalMD, subnetMD, routerMD,
                          globalWUL, subnetWUL, routerWUL,
                          node_id, rc, ts))
                    if tag == tools.cx.constants.SS_KEY_DOWNLOAD_INTERVAL:
                        (downloadInterval,) = struct.unpack('>L', value)
                        self.dbInsert.execute(
                          '''UPDATE bacon_settings 
                          SET download_interval=?
                          WHERE node_id=? and rc=? and ts=?''',
                          (downloadInterval, node_id, rc, ts))
                    if tag == tools.cx.constants.SS_KEY_MAX_DOWNLOAD_ROUNDS:
                        (maxDownloadRounds,) = struct.unpack('>H', value)
                        self.dbInsert.execute(
                          '''UPDATE bacon_settings 
                          SET max_download_rounds=?
                          WHERE node_id=? and rc=? and ts=?''',
                          (maxDownloadRounds, node_id, rc, ts))

