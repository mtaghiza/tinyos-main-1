#!/usr/bin/env python
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
