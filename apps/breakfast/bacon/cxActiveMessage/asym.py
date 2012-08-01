#!/usr/bin/env python
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

def usage():
    print >> sys.stderr, """Usage: python %s <db file> <src> <dest> <buffer width> [src_sn dest_sn]
  Compute the set of forwarders between src and dest based on flood
  traces. Specifying src_sn and dest_sn uses just a single pair of
  floods.

  Output:

  src, dest, src-dest distance, dest-src distance, num-of-forwarders, [forwarders]
"""

if __name__ == '__main__':
    if len(sys.argv) < 5:
        usage()
        sys.exit(1)
    db = sys.argv[1]
    src = sys.argv[2]
    dest = sys.argv[3]
    bufferWidth = sys.argv[4]
    c = sqlite3.connect(db)
    if len(sys.argv) > 5:
        sn_s = sys.argv[5]
        sn_d = sys.argv[6]
        (d_sd, d_ds, fwd) = instantForwarders(c, src, dest, sn_s, sn_d, bufferWidth) 
    else:
        (d_sd, d_ds, fwd) = aggForwarders(c, src, dest, bufferWidth) 
#    if d_sd < 0 or d_ds < 0:
#        pass
#    else:
    print "%s, %s, %f, %f, %d,"%(src, dest, d_sd, d_ds, len(fwd)), sorted(fwd)
