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

import time
import sqlite3
import tools.cx.constants as constants


class StatusTimeRefListener(object):
    def __init__(self, db, refCallBack=None):
        self.downloadStart = None
        self.db = db
        self.refCallBack = refCallBack

    def receive(self, src, msg):
        neighbors = [v for v in msg.get_neighbors() if v != constants.BCAST_ADDR]
        print "REF", self.downloadStart, msg.addr, msg.get_wakeupRC(), msg.get_wakeupTS(), msg.get_dataPending(), neighbors
        print "Status", msg
        q0 = ''' INSERT INTO base_reference
          (node1, rc1, ts1, unixTS) VALUES
          (?, ?, ?, ?)'''
        self.db.insert.execute(q0, 
          (msg.addr, msg.get_wakeupRC(), msg.get_wakeupTS(),
            self.downloadStart))
        q1 = '''INSERT INTO node_status 
          (node_id, ts, barcode_id, writeCookie, subnetChannel, sampleInterval, role) 
          VALUES (?, ?, ?, ?, ?, ?, ?)'''
        barcodeText = '0x'+''.join(['%02x'%v for v in reversed(msg.get_barcode())])
        self.db.insert.execute(q1, (msg.addr, 
          time.time(),
          barcodeText,
          msg.get_writeCookie(),
          msg.get_subnetChannel(), 
          msg.get_sampleInterval(),
          msg.get_role()))
        if self.refCallBack:
            self.refCallBack(msg.addr, neighbors, msg.get_pushCookie(),
                msg.get_writeCookie(), msg.get_missingLength())
