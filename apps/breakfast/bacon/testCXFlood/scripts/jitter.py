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

from laParser import *
import sys

def endPacketOffsets(data):
    f1 = findEdges(data, 6, 1)
    f2 = findEdges(data, 7, 1)
    if (len(f1) != len(f2)):
        print >> sys.stderr, "data length mismatch"
        return 
    else:
        offsets = [(abs(r[0]-l[0]),l,r) for (l,r) in zip(f1,f2)]
        return offsets

def sfdForwardOffsets(data):
    f1 = findEdges(data, 1, 1)
    f2 = findEdges(data, 2, 1)
    #keep only the edges where SFD 0 is low
    f1 = [r for r in f1 if r[1][0] == 0]
    f2 = [r for r in f2 if r[1][0] == 0]
    if (len(f1) != len(f2)):
        print >> sys.stderr, "data length mismatch"
        return 
    else:
        offsets = [(abs(r[0]-l[0]),l,r) for (l,r) in zip(f1,f2)]
        return offsets

def stxForwardOffsets(data):
    f1 = findEdges(data, 4, 1)
    f2 = findEdges(data, 5, 1)
    if (len(f1) != len(f2)):
        print >> sys.stderr, "data length mismatch"
        return 
    else:
        offsets = [(abs(r[0]-l[0]),l,r) for (l,r) in zip(f1,f2)]
        return offsets

   

if __name__=='__main__':
    data = parse(open(sys.argv[1], 'r'))
    if '--sfdForward' in sys.argv:
        results = sfdForwardOffsets(data)
    elif '--endPacketInterrupt' in sys.argv:
        results = endPacketOffsets(data)
    elif '--stxForward' in sys.argv:
        results = stxForwardOffsets(data)

    if '--debug' in sys.argv:
        for o in results:
            print o
    else:
        for o in results:
            print o[0]
