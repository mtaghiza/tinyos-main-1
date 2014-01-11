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

import sqlite3
import sys

#src, dest, src, bw, dest, src, dest, bw
forwarders_bidirectional_query = """
SELECT 
  sd.dest, sd.sdd,
  ds.dsd, sd.sdd+ds.dsd
FROM ( 
  SELECT dest, DEPTH_TABLE.avgDepth as sdd
  FROM DEPTH_TABLE 
  JOIN (
    SELECT avgDepth FROM DEPTH_TABLE where src=? and dest = ?) sd_depth 
  WHERE src = ? and DEPTH_TABLE.avgDepth < sd_depth.avgDepth + ?) sd
JOIN ( 
  SELECT dest, DEPTH_TABLE.avgDepth as dsd
  FROM DEPTH_TABLE 
  JOIN (
    SELECT avgDepth FROM DEPTH_TABLE where src=? and dest = ?) ds_depth 
  WHERE src = ? and DEPTH_TABLE.avgDepth < ds_depth.avgDepth + ?) ds 
ON ds.dest = sd.dest ORDER BY sd.sdd"""

depth_query = """
SELECT avgDepth
FROM DEPTH_TABLE
WHERE src=? and dest=?
"""

next_tx_query = """
SELECT min(sn), min(ts)
FROM TX_ALL
WHERE src=? and ts > ?
"""

drop_temp_depth = """DROP TABLE IF EXISTS tmp_depth"""
create_temp_depth = """
CREATE TEMP TABLE tmp_depth AS
  SELECT src, dest, depth as avgDepth
  FROM rx_all 
  WHERE (src=? and sn=?) OR (src=? and sn=?)"""


def forwarders(c, src, dest, bw, fwd_q, depth_q):
    sd = c.execute(fwd_q, (src, dest, src, bw, dest, src, dest, bw))
    fwd = set([ node for (node, sdd, dsd, tot) in sd])
    d_sd = c.execute(depth_q, (src, dest)).fetchone()
    if not d_sd:
        d_sd = -1
    else:
        d_sd = d_sd[0]
    d_ds = c.execute(depth_q, (dest, src)).fetchone()
    if not d_ds:
        d_ds = -1
    else:
        d_ds = d_ds[0]
    if (d_ds != -1) and (d_sd != -1):
        fwd.add(int(src))
        fwd.add(int(dest))
    return (d_sd, d_ds, fwd)

def aggForwarders(c, src, dest, bw):
    fwd_q = forwarders_bidirectional_query.replace("DEPTH_TABLE", "agg_depth")
    depth_q = depth_query.replace("DEPTH_TABLE", "agg_depth")
    return forwarders(c, src, dest, bw, fwd_q, depth_q)

def instantForwarders(c, src, dest, sn_s, sn_d, bw):
    c.execute(drop_temp_depth)
    c.execute(create_temp_depth, (src, sn_s, dest, sn_d))
    fwd_q = forwarders_bidirectional_query.replace("DEPTH_TABLE", "tmp_depth")
    depth_q = depth_query.replace("DEPTH_TABLE", "tmp_depth")
    return forwarders(c, src, dest, bw, fwd_q, depth_q)

def spForwarders(c, src, dest, bw):
    fwd_q = forwarders_bidirectional_query.replace("DEPTH_TABLE", "depth")
    depth_q = depth_query.replace("DEPTH_TABLE", "depth")
    return forwarders(c, src, dest, bw, fwd_q, depth_q)

def usage():
    print >> sys.stderr, """Usage: 
  python %s -s <src> -d <dest> -w <buffer width> [-c <cx db file> ] [-S <single-path db file>] [-i src_sn,dest_sn] 

  Compute the set of forwarders between src and dest based on flood
  traces. 

    OPTIONS

    -s, -d, and -w indicate which nodes act as src and dest, and how
    large the buffer around the shortest paths should be. 
  
    -i src_sn dest_sn: use just a single pair of floods (identified by
    sn) from CX trace.
    
    -S indicates the db is from running a single-path connectivity test
    (see apps/breakfast/bacon/connectivityTest).
  
    -c indicates the db is from a CX trace.

  Output (one of -c or -S supplied):

    type, src, dest, src-dest distance, dest-src distance, num-of-forwarders, [forwarders]
  
  where type is "cx" or "sp"

  Output (both -c and -S supplied):
  
    "comp", src, dest, similarity, [sp forwarders], [cx forwarders]

  where similarity is given using Jaccard's similarity index.
"""%(sys.argv[0])

def clForwarders(args):
    if len(args) < 5:
        usage()
        sys.exit(1)
    opts = zip(args, args[1:])
    cxConn = None
    spConn = None
    bw = -1
    src = -1
    dest = -1
    sn_s = -1
    sn_d = -1
    cxResults = None
    spResults = None
    for (name, val) in opts:
        if name == '-c':
            cxConn = sqlite3.connect(val)
        if name == '-S':
            spConn = sqlite3.connect(val)
        if name == '-w':
            bw = val
        if name == '-s':
            src = val
        if name == '-d':
            dest = val
        if name == '-i':
            [sn_s, sn_d] = val.split(',')
    if cxConn:
        if '-i' in args:
            cxResults = instantForwarders(cxConn, src, dest, sn_s, sn_d, bufferWidth) 
        else:
            cxResults = aggForwarders(cxConn, src, dest, bw) 
    
    if '-S' in args:
        spResults = spForwarders(spConn, src, dest, bw) 

    if spResults and cxResults:
        spFwd = spResults[-1]
        cxFwd = cxResults[-1]
        if not len(spFwd | cxFwd):
            si = -1
        else:
            si = float(len(spFwd & cxFwd))/len(spFwd | cxFwd)
        print "comp, %s, %s, %f, %d, %d"%(src, dest, si, len(spFwd), len(cxFwd)),
        if '-v' in args:
            print ", %s, %s"%(sorted(spFwd), sorted(cxFwd))
        else:
            print ""
    else:
        t =""
        if spResults:
            (d_sd, d_ds, fwd) = spResults
            t = "sp"
        elif cxResults:
            (d_sd, d_ds, fwd) = cxResults
            t = "cx"
        else:
            print >> sys.stderr, "Error: no results."
            sys.exit(1)
        print "%s, %s, %s, %f, %f, %d,"%(t, src, dest, d_sd, d_ds, len(fwd)), sorted(fwd)    

if __name__ == '__main__':
    if len(sys.argv) < 3:
        usage()
        sys.exit(1)
    clForwarders(sys.argv[1:])
