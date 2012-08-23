#!/usr/bin/env python
import sys

def checksum(record):
    return ((sum(record) & 0xff) ^ 0xff) + 1

if __name__ == '__main__':
    addr = int(sys.argv[1], 16)
    rt = int(sys.argv[2], 16)

    data = sys.argv[3]
    dataStr = [l+r for (l,r) in zip(data[0::2], data[1::2])]
    dataInt = [int(s, 16) for s in dataStr]
    l = len(dataInt)
    crc = checksum([l]+[(addr&0xff00)>>8, addr&0xff] + [rt] + dataInt)
    print ":%02X%04X%02X"%(l, addr, rt)+data+"%02X"%crc
