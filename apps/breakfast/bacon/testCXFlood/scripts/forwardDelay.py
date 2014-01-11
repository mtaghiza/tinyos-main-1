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
import pdb

def sfdForwardDelays(data, forwarder=1):
    starts = findEdges(data, 0, 1)
    forwards = findEdges(data, forwarder, 1)

    #original transmissions: root-start high, forwarder low
    starts = [r for r in starts if r[1][3] == 1 and r[1][forwarder] == 0 ]
    #forwards: root-start high, root low
    forwards = [r for r in forwards if r[1][3] == 1 and r[1][0] == 0]
    #pdb.set_trace()
    if len(forwards) != len(starts):
        print >> sys.stderr, "data length mismatch"
        return
    else:
        offsets = [(abs(r[0]-l[0]),l,r) for (l,r) in zip(starts,forwards)]
        return offsets
 
if __name__=='__main__':
    data = parse(open(sys.argv[1], 'r'))
    results = sfdForwardDelays(data, 1)
    if '--debug' in sys.argv:
        for o in results:
            print o
    else:
        for o in results:
            print o[0]

