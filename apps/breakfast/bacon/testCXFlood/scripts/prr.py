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

import sys
import re


if __name__ == '__main__':
    src = sys.stdin
    if len(sys.argv) > 1:
        if sys.argv[1] != '-':
            src = open(sys.argv[1], 'r')

    firstSns = {}
    lastSns = {}
    counts = {}
    pattern = re.compile("RX: Sender: ([0-9]+) Receiver: ([0-9]+) SN: ([0-9]+)")

    for line in src:
        m = pattern.match(line.strip())
        if m:
            receiver = int(m.groups()[1])
            sender = int(m.groups()[0])
            sn = int(m.groups()[2])

            if receiver not in firstSns:
                firstSns[receiver] = {}
                lastSns[receiver] = {}
                counts[receiver] = {}
            mf = firstSns[receiver]
            ml = lastSns[receiver]
            mc = counts[receiver]

            if sender not in mf:
                mc[sender] = 0
                mf[sender] = sn
            ml[sender] = sn
            mc[sender] += 1

    for receiver in sorted(firstSns):
        f = firstSns[receiver]
        l = lastSns[receiver]
        c = counts[receiver]
        for sender in f:
            prr = (float(c[sender])/
                (float(l[sender]-f[sender]+ 1)))
            print "%d,%d,%.4f"%(sender, receiver,  prr)
