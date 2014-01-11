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

if __name__ == '__main__':
    #file
    #col0
    #edge0
    #col1
    #edge1
    #filterCol0
    #filterCol0 state
    #filterCol1
    #filterCol1 state
    records = parse(open(sys.argv[1], 'r'))
    col0 = int(sys.argv[2])
    edgeType0 = int(sys.argv[3])
    col1 = int(sys.argv[4])
    edgeType1 = int(sys.argv[5])
    fCol0 = int(sys.argv[6])
    fState0 = int(sys.argv[7])
    fCol1 = int(sys.argv[8])
    fState1 = int(sys.argv[9])

    edge0 = findEdges(records, col0, edgeType0)
    edge0 = [r for r in edge0 
      if r[1][fCol0] == fState0 and r[1][fCol1] == fState1]
    edge1 = findEdges(records, col1, edgeType1)
    edge1 = [r for r in edge1
      if r[1][fCol0] == fState0 and r[1][fCol1] == fState1]

    if (len(edge0) != len(edge1)):
        print "TROUBLE"
        print len(edge0), len(edge1)
        sys.exit(1)
    for ((lt,ld), (rt, rd) ) in zip(edge0, edge1):
        print lt, rt-lt


