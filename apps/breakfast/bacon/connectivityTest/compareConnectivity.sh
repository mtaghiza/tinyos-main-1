#!/bin/bash
if [ $# -ne 2 ]
then
  echo "Usage: $0 <connectivity DB> <cx db>" 1>&2
  exit 1
fi

basicDb=$1
cxDb=$2

txPower=195
prrThresh=0.95

python depths.py $basicDb $txPower $prrThresh

sqlite3 $cxDb << EOF
attach database '$basicDb' as basic;
SELECT * from basic.tx limit 5;

SELECT 
  agg_depth.src as src, 
  agg_depth.dest as dest, 
  agg_depth.avgDepth as cxDepth, 
  depth.depth as depth,
  depth.depth - agg_depth.avgDepth as cxImprovement,
  agg_depth.sdDepth as cxSdev
FROM agg_depth 
JOIN depth 
  ON agg_depth.src = depth.src 
  AND agg_depth.dest = depth.dest 
WHERE agg_depth.src = 0 OR agg_depth.dest = 0 
ORDER BY depth.depth;
EOF
