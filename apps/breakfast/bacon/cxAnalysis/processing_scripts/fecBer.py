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
import pdb

encoding = [
  0x00, 0x87, 0x99, 0x1e,
  0xaa, 0x2d, 0x33, 0xb4,
  0x4b, 0xcc, 0xd2, 0x55,
  0xe1, 0x66, 0x78, 0xff,
]
decoding = [
  0x00, 0x00, 0x00, 0xff, 0x00, 0xff, 0xff, 0x01, 
  0x00, 0xff, 0xff, 0x08, 0xff, 0x05, 0x03, 0xff, 
  0x00, 0xff, 0xff, 0x06, 0xff, 0x0b, 0x03, 0xff, 
  0xff, 0x02, 0x03, 0xff, 0x03, 0xff, 0x03, 0x03, 
  0x00, 0xff, 0xff, 0x06, 0xff, 0x05, 0x0d, 0xff, 
  0xff, 0x05, 0x04, 0xff, 0x05, 0x05, 0xff, 0x05, 
  0xff, 0x06, 0x06, 0x06, 0x07, 0xff, 0xff, 0x06, 
  0x0e, 0xff, 0xff, 0x06, 0xff, 0x05, 0x03, 0xff, 
  0x00, 0xff, 0xff, 0x08, 0xff, 0x0b, 0x0d, 0xff, 
  0xff, 0x08, 0x08, 0x08, 0x09, 0xff, 0xff, 0x08, 
  0xff, 0x0b, 0x0a, 0xff, 0x0b, 0x0b, 0xff, 0x0b, 
  0x0e, 0xff, 0xff, 0x08, 0xff, 0x0b, 0x03, 0xff, 
  0xff, 0x0c, 0x0d, 0xff, 0x0d, 0xff, 0x0d, 0x0d, 
  0x0e, 0xff, 0xff, 0x08, 0xff, 0x05, 0x0d, 0xff, 
  0x0e, 0xff, 0xff, 0x06, 0xff, 0x0b, 0x0d, 0xff, 
  0x0e, 0x0e, 0x0e, 0xff, 0x0e, 0xff, 0xff, 0x0f, 
  0x00, 0xff, 0xff, 0x01, 0xff, 0x01, 0x01, 0x01, 
  0xff, 0x02, 0x04, 0xff, 0x09, 0xff, 0xff, 0x01, 
  0xff, 0x02, 0x0a, 0xff, 0x07, 0xff, 0xff, 0x01, 
  0x02, 0x02, 0xff, 0x02, 0xff, 0x02, 0x03, 0xff, 
  0xff, 0x0c, 0x04, 0xff, 0x07, 0xff, 0xff, 0x01, 
  0x04, 0xff, 0x04, 0x04, 0xff, 0x05, 0x04, 0xff, 
  0x07, 0xff, 0xff, 0x06, 0x07, 0x07, 0x07, 0xff, 
  0xff, 0x02, 0x04, 0xff, 0x07, 0xff, 0xff, 0x0f, 
  0xff, 0x0c, 0x0a, 0xff, 0x09, 0xff, 0xff, 0x01, 
  0x09, 0xff, 0xff, 0x08, 0x09, 0x09, 0x09, 0xff, 
  0x0a, 0xff, 0x0a, 0x0a, 0xff, 0x0b, 0x0a, 0xff, 
  0xff, 0x02, 0x0a, 0xff, 0x09, 0xff, 0xff, 0x0f, 
  0x0c, 0x0c, 0xff, 0x0c, 0xff, 0x0c, 0x0d, 0xff, 
  0xff, 0x0c, 0x04, 0xff, 0x09, 0xff, 0xff, 0x0f, 
  0xff, 0x0c, 0x0a, 0xff, 0x07, 0xff, 0xff, 0x0f, 
  0x0e, 0xff, 0xff, 0x0f, 0xff, 0x0f, 0x0f, 0x0f, 
]

#From: http://www.lammertbies.nl/forum/viewtopic.php?t=49
class CRC_CCITT: 
   def __init__(self): 
      self.tab=256*[[]] 
      for i in xrange(256): 
         crc=0 
         c = i << 8 
         for j in xrange(8): 
            if (crc ^ c) & 0x8000: 
               crc = ( crc << 1) ^ 0x1021 
            else: 
               crc = crc << 1 
            c = c << 1 
            crc = crc & 0xffff 
         self.tab[i]=crc 
    
   def update_crc(self, crc, c): 
      short_c=0x00ff & (c % 256) 
      tmp = ((crc >> 8) ^ short_c) & 0xffff 
      crc = (((crc << 8) ^ self.tab[tmp])) & 0xffff 
      return crc 


def computeCRC(b):
    test=CRC_CCITT() 
    crcval = 0
    for (l,r) in zip(b[::2], b[1::2]):
        v = ((l <<8) + r)
        crcval = test.update_crc(crcval, v) 
    return crcval

def encode(b):
    encoded = []
    for b0 in b:
        encoded += [ encoding[b0>>4], encoding[b0&0x0f]]
    return encoded

def decode(b):
    decoded = []
    for (b0, b1) in zip(b[::2], b[1::2]):
        decoded.append( (0xf0&(decoding[b0] << 4)) | decoding[b1])
    return decoded

def toBytes(s):
    return [int(l+r, 16) for (l,r) in zip(s[::2], s[1::2])]

def findErrors(b):
    errors = []
    p = 7
    while b:
        if (b & 0x01):
            errors.append(p)
        b = (b >> 1)
        p -= 1
    return reversed(errors)

dec_indices = [22]
inc_indices = [11]
countIndex= 11
snIndex=9
payloadEnd=50

if __name__ == '__main__':
    f = sys.stdin
    printLocations = 0
    countOfInterest = 2
    printRaw = 0
    printDecoded = 1
    printOrig = 0
    if len(sys.argv) > 1:
        for (o,v) in zip(sys.argv, sys.argv[1:]):
            if o == '-f':
                f = open(v, 'r')
            if o == '-l':
                printLocations = int(v)
            if o == '-r':
                printRaw = int(v)
            if o == '-d':
                printDecoded = int(v)
            if o == '-o':
                printOrig = int(v)
    b = []
    lastB = []
    refBytes = []
    refDec = []
    refSN = -1
    for line in f:
        l = line.strip()
        #print "original", l
        s = l.split()[3]
        ts = float(l.split()[0])
        lastB = b
        #cut off dead space at end of packet and remove CRC
        b = toBytes(s)[:payloadEnd]
        decoded = decode(b)
        if len(decoded) < 14:
            continue
        sn = (decoded[snIndex] << 8) + decoded[snIndex+1]
        count = decoded[countIndex]
        rssi = int(l.split()[4])
        lqi = int(l.split()[5])
#        pdb.set_trace()
        #TODO: output CXS line: read the other header fields
        outerCrcPassed = 1 if int(l.split()[-1]) != 0 else 0
#        decodedCRC = decoded[-2:]
#        decoded = decoded[:-2]
        #validate inner CRC
#        innerCrcPassed = computedCrc == (decodedCrc[0] << 8) + decodedCrc[1]
        #TODO: remove when working crc implementation available
#        decodedCRC = []

        if outerCrcPassed and count==1:
            for i in dec_indices:
                decoded[i] -= (countOfInterest -1)
            for i in inc_indices:
                decoded[i] += (countOfInterest -1)
            computedCrc = computeCRC(decoded)
            ##TODO: convert CRC to bytes
            crcA = []
            refBytes = encode(decoded + crcA)
            refDec = decoded
            refSN = sn
            errorTotal = 0
            if printOrig:
                print "ORIG",ts, sn
            if printRaw:
                print "RAW", ts, sn, count, ''.join('%02X'%v for v in refBytes), rssi, lqi
            if printDecoded:
                print "DEC", ts, sn, count,''.join('%02X'%v for v in decoded) 
        else:
            rb = refBytes
            if len(b) != len(rb):
                continue
            if sn == refSN and refBytes and count == countOfInterest:
              errors = [ (v ^ refV) for (v, refV) in zip(b, rb)]
              errorLocs = [findErrors(v) for v in errors]
#              pdb.set_trace()
              errorLocs = [ [i*8+v for v in l] for (i, l) in enumerate(errorLocs)]
              errorLocs = reduce(lambda x,y: x+y, errorLocs, [])
              errorTotal = len(errorLocs)
              if printLocations: 
                  for l in errorLocs:
                      print "LOC",ts,l
              byteErrors = [ d != refD for (d, refD) in zip(decoded, refDec)]
              byteErrorCount = sum(byteErrors)
              #TODO: output innerCrcPassed and outerCrcPassed
              print "BER", ts, sn, outerCrcPassed, count, errorTotal, len(refBytes)*8, byteErrorCount
              if printRaw:
                  print "RAW", ts, sn, count, ''.join('%02X'%v for v in b), rssi, lqi
              if printDecoded:
                  print "DEC", ts, sn, count,''.join('%02X'%v for v in decoded) 
