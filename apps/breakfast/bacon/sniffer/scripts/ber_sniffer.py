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

import logging
import sys
import re
import pdb
import decode

logging.basicConfig(level = logging.INFO)

def toInt(x):
    return reduce(lambda l,r: (l<<8) + r, x)

def findErrors(b):
    errors = []
    p = 7
    while b:
        if (b & 0x01):
            errors.append(p)
        b = (b >> 1)
        p -= 1
    return errors

def countErrors(b):
    acc = 0
    while b:
        acc += (b & 0x01)
        b = (b >> 1)
    return acc

def src(pkt):
    if len(pkt) < 10:
        return -1
    else:
        return toInt(reversed(pkt[8:10]))
   
def sn(pkt):
    if len(pkt) < 14:
        return -1 
    else:
        return toInt(pkt[12:14])

def count(pkt):
    if len(pkt) < 15:
        return -1
    else:
        return pkt[14]

def extractPacket(line):
    r = [int(v, 16) for v in line.strip().split()[2:]]
    pkt = r[0:-3]
    crcPassed = (r[-3] == 0x80)
    pktComm = pkt[0:14]+pkt[15:]
    return (pkt, pktComm, pktComm, pkt, crcPassed)

def decodePacket(line):
    r = [int(v, 16) for v in line.strip().split()[2:]]
    pkt = r[0:-3]
    crcPassed = (r[-3] == 0x80)
    lqi = r[-2]
    rssi = r[-1]
    dpkt = decode.decode(pkt)
    pktComm = pkt[0:28]+pkt[30:-5]
#    pdb.set_trace()
    return (dpkt, pktComm, decode.decode(pktComm), pkt, crcPassed)

def computeStats(fn, fecEnabled):
    lp = re.compile("""^[0-9]*.[0-9]* [0-9]*( [0-9A-F]{2})* -[0-9]*""")
    f = open(fn, 'r')
    prev = None
    sns = []
    results = []
    nonMatched = 0
    lineCount = 0
    if fecEnabled:
        toPacket = decodePacket
    else:
        toPacket = extractPacket
    for line in f:
        lineCount += 1
        if not lp.match(line):
            nonMatched +=1
#            print "No match:", line
        else:
            #decode for sn, count, contents
            (dpkt, pktComm, dpktComm, pkt, crcPassed) = toPacket(line)
            #record original broadcast info
            if count(dpkt) == 1 and src(dpkt) == 0:
                prev = (dpkt, pktComm, dpktComm)
                sns.append(sn(dpkt))
            #rebroadcast
            if count(dpkt) == 2 and src(dpkt) == 0 and sn(dpkt) == sn(prev[0]):
                rawErrorOffsets = [findErrors(lv ^ rv) for (lv, rv) in
                  zip(prev[1], pktComm)] 
                rbe = []
                for (i, eo) in enumerate(rawErrorOffsets):
                    for b in eo:
                        rbe.append(i*8+b)
                errorBytes = [ 1 if countErrors(lv ^ rv) else 0 for (lv, rv) in zip(prev[2], dpktComm)]
#                pdb.set_trace()
                #results: (data comparison pass/fail, crc pass/fail, 
                # number of bit errors, packet len
                # in bits, positions of bit errors)
                results.append((1 if sum(errorBytes) == 0 else 0,
                  crcPassed,
                  len(rbe), 
                  len(pkt)*8, 
                  rbe) )
    rxCount = len(results)
    rxDataCount = sum([r[0] for r in results])
    rxCrcCount = sum([r[1] for r in results])
    txCount = float(1 + sns[-1] - sns[0])
    totalBits = float(sum([r[3] for r in results]))
    bitErrors = float(sum([r[2] for r in results]))
    #overall PRR, including errors
    prrAll = rxCount / txCount
    #overall PRR, data passed
    prrDataPassed = rxDataCount/txCount
    #overall PRR, crc passed
    prrCrcPassed = rxCrcCount/txCount
    ber = bitErrors/ totalBits
    #for debugging/quality control
    fractionInvalid = float(nonMatched)/lineCount
    r = {'ber':ber, 'prrCrcPassed':prrCrcPassed,
    'prrDataPassed':prrDataPassed, 'prrAll':prrAll,
    'fractionInvalid':fractionInvalid}
    return r
    

if __name__ == '__main__':
    """Run with sniffer files as arguments, config encoded in name:
      Naming convention: dir/sm_x_np_x_fec_x_sr_x_nc_x
      sm: synch mode (MDMCFG2.SYNC_MODE)
      np: number of preamble bytes (MDMCFG1.NUM_PREAMBLE)
      fec: 0= off 1 = on
      sr: in Kbps
      nc: node count (estimated)
    """
    print "FEC SM NP SR NC BER PCRC PDATA PALL"
    for fn in sys.argv[1:]:
        descriptor_str = fn.split('/')[-1].split('_')
        descriptor = dict([(k , int(v)) for (k,v) in
          zip(descriptor_str[::2], descriptor_str[1::2])])
        result = computeStats(fn, descriptor['fec'])
        print "%(fec)i %(sm)i %(np)i %(sr)i %(nc)i"%descriptor,
        print "%(ber).4f %(prrCrcPassed).4f %(prrDataPassed).4f %(prrAll).4f"%result
        logging.debug("File %s fraction invalid: %.4f"%(fn,
          result['fractionInvalid']))
