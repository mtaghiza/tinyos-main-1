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

import tos
import sys

AM_CMD = 0xDC
AM_RECEIVER_REPORT = 0xDD
AM_SENDER_REPORT = 0xDE

CMD_NEXT=0x01
CMD_SEND=0x02

class CmdPacket(tos.Packet):
    def __init__(self, packet):
        tos.Packet.__init__(self,
                            [('cmd',            'int', 1),
                             ('send1Offset',    'int', 2),
                             ('sendCount',      'int', 2)],
                            packet)

class ReceiverReportPacket(tos.Packet):
    def __init__(self, packet):
        tos.Packet.__init__(self,
                            [('configId',       'int', 2),
                             ('seqNum',         'int', 2),
                             ('received',       'int', 1),
                             ('rssi',           'int', 2),
                             ('lqi',            'int', 2),
                             ('send1Offset',            'int', 2),],
                            packet)

class SenderReportPacket(tos.Packet):
    def __init__(self, packet):
        tos.Packet.__init__(self,
                            [('configId',       'int', 2),
                             ('seqNum',         'int', 2)],
                            packet)


def sendNextCmd():
    cmdp = CmdPacket((CMD_NEXT, 0, 0))
    am.write(cmdp, AM_CMD)

def sendSendCmd(send1Offset=0, sendCount=1):
    sendp = CmdPacket((CMD_SEND, send1Offset, sendCount))
    am.write(sendp, AM_CMD)
    for i in range(sendCount):
        p = am.read(timeout=2)
        if p:
            rpt = ReceiverReportPacket(p.data)
            print rpt 
        else:
            print "no response"
            break

def runTest(offsets, sendCount):
    sendNextCmd()
    for offset in offsets:
        sendSendCmd(offset, sendCount)

def runBatch(numRounds, offsets, sendCount):
    for i in range(numRounds):
        runTest(offsets, sendCount)

def usage():
    print "USAGE: %s <device> <numRounds> <sendCount> [offset ...]"%sys.argv[0]

if __name__ == '__main__':
    if len(sys.argv) < 5:
        usage()
        sys.exit(1)
    s = tos.Serial(sys.argv[1], 115200, debug=False)
    am = tos.AM(s)

    [numRounds, sendCount] = map(int, sys.argv[2:4])
    offsets = map(int, sys.argv[4:])
    runBatch(numRounds, offsets, sendCount)
