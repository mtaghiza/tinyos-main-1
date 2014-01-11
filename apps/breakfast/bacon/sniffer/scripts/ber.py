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
from crc import findErrors

symbol_length_list = [833.69182, 26.052872, 5.715681157013905, 4.0009762, 1000.0 / 2.398968, 1000.0 / 4.797935, 1000.0 / 9.992599, 1000.0 / 76.766968, 1000.0 / 99.975586, 4.0009762 * 2.0]
symbol_rate_label_list = ['1p2K', '38p4K', '175K', '250K', '2p4K', '4p8K', '10K', '76p8K', '100K', '125K']
symbol_rate_list = [1200, 38400, 175000, 250000, 2400, 4800, 10000, 76800, 100000, 125000]

header = [int(v) for v in "78 22 0 255 255 1 0 63 220".split()]
payload = [int(v) for v in  "251 172 224 190 38 216 237 74 10 183 249 99 173 204 18 192 229 209 82 248 150 23 1 91 65 136".split()]

def computeBER(fn):
    """Compute BER and other reception stats. Output tuple:
    (symbolRate, txpower2, delay, ber, crc, prr_all, prr_passed)

    ber is computed only over packets which we received, so if
    preamble was corrupted, this undercounts errors.

    crc is the fraction of received packets with failed crcs.

    prr_all is fraction of total packets sent which were received
    (regardless of CRC error). 

    prr_passed is fraction of total packets received with passing CRC.
    """

    f = open(fn, 'r')
    cfg = int(fn.split('/')[-1].split('_')[1])
    txp2 = int(fn.split('/')[-1].split('_')[3], 16)
    delay = int(fn.split('/')[-1].split('-')[-1].split('.')[0])
    failures = []
    rxCount = 0
    bitCount = 0
    errorCount = 0
    crcFailures = 0
    rxCount = 0
    for line in f:
        if 'RX' in line:
            pkt = [int(v) for v in line.split()[7:]]
            hdr = pkt[-9:]
            pl  = pkt[:-9]
            ref = header+payload[:len(pl)]
            errorOffsets = [findErrors(lv ^rv) for (lv, rv) in zip(ref, hdr+pl)]
            bitErrors = []
            for (i, eo) in enumerate(errorOffsets):
                for b in eo:
                    bitErrors.append(i*8+b)
                    errorCount+=1
            failures.append((1, bitErrors))
            bitCount += 8*len(ref)
#            print (line.split()[:10], line.split()[5])
            if int(line.split()[5]) == 0:
                crcFailures +=1
            rxCount += 1
            maxSN = int(line.split()[2])
    return (symbol_rate_list[cfg], txp2, delay, 
      float(errorCount)/bitCount, 
      float(crcFailures)/rxCount, 
      float(rxCount)/(maxSN+1),
      float(rxCount - crcFailures)/(maxSN+1))
    

if __name__ == '__main__':
    print "SR TXP Delay BER CRC_ERR PRR_ALL PRR_PASSED"
    for fn in sys.argv[1:]:
        (sr, txp, delay, ber, crc, prrAll, prrTot) = computeBER(fn)
        print sr, txp, delay, ber, crc, prrAll, prrTot
