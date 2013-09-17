#!/usr/bin/env python
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
        if not self.connected:
            self.connection = sqlite3.connect(self.dbName)
        q ='''INSERT OR IGNORE INTO bacon_settings 
           (node_id, cookie, rc, ts, offset, data, barcode_id, bacon_interval, toast_interval) values 
           (?,       ?,      ?,  ?,  ?,      ?,    '',         ?,              ?)'''
        t = self.unpack(source, cookie, data)
        (node_id, cookie, rc, ts, offset, tlv ) = t
        print "Decoded Bacon Settings"
        self.connection.execute(q, 
          (node_id, cookie, rc, ts, offset, tlv, 
           tools.cx.constants.DEFAULT_SAMPLE_INTERVAL,
           tools.cx.constants.DEFAULT_SAMPLE_INTERVAL))
        #if this is the second half, join em up
        if offset == 64:
            pass
            chunks = self.connection.execute('''select data from
            bacon_settings 
            WHERE node_id = ? and rc=? and ts=? 
            ORDER BY offset''', 
            (node_id, rc, ts)).fetchall()
#             print chunks
            if (len(chunks) == 2):
                tlv = reduce(lambda l,r: l[0]+r[0], chunks)
                for (tag, length, value) in Decoder.tlvIterator(tlv):
                    print "next (t,l,v)", hex(tag), length, ' '.join([hex(ord(c)) for c in value])
                    if tag == tools.cx.constants.SS_KEY_GLOBAL_ID:
                        baconIDText = Decoder.toHexStr(buffer(value))
                        self.connection.execute('''UPDATE
                        bacon_settings SET barcode_id = ? WHERE
                        node_id=? and rc = ? and ts=?''',
                          (baconIDText, node_id, rc, ts))
                    if tag == tools.cx.constants.SS_KEY_BACON_SAMPLE_INTERVAL:
                        (baconSampleInterval,) = struct.unpack('>L', value)
                        self.connection.execute('''UPDATE bacon_settings
                        SET bacon_interval = ? 
                        WHERE node_id=? and rc=? and ts=?''',
                        (baconSampleInterval, node_id, rc, ts))
                    if tag == tools.cx.constants.SS_KEY_TOAST_SAMPLE_INTERVAL:
                        (toastSampleInterval,) = struct.unpack('>L', value)
                        self.connection.execute('''UPDATE bacon_settings
                        SET toast_interval = ? 
                        WHERE node_id=? and rc=? and ts=?''',
                        (toastSampleInterval, node_id, rc, ts))
                    if tag == tools.cx.constants.SS_KEY_LOW_PUSH_THRESHOLD:
                        (lpt,) = struct.unpack('>B', value)
                        self.connection.execute(
                          '''UPDATE bacon_settings 
                          SET low_push_threshold=?
                          WHERE node_id=? and rc=? and ts=?''',
                          (lpt, node_id, rc, ts))
                    if tag == tools.cx.constants.SS_KEY_HIGH_PUSH_THRESHOLD:
                        (hpt,) = struct.unpack('>B', value)
                        self.connection.execute(
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
                        self.connection.execute(
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
                        self.connection.execute(
                          '''UPDATE bacon_settings 
                          SET download_interval=?
                          WHERE node_id=? and rc=? and ts=?''',
                          (downloadInterval, node_id, rc, ts))
                    if tag == tools.cx.constants.SS_KEY_MAX_DOWNLOAD_ROUNDS:
                        (maxDownloadRounds,) = struct.unpack('>B', value)
                        self.connection.execute(
                          '''UPDATE bacon_settings 
                          SET max_download_rounds=?
                          WHERE node_id=? and rc=? and ts=?''',
                          (maxDownloadRounds, node_id, rc, ts))


        self.connection.commit()
        self.connection.close()

