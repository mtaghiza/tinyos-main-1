#!/bin/bash
dbDir=$1
echo "src,dest,retx,prr_rl,prr_lr"
set -x
for db in $dbDir/nsfb_f_all_1_0.10.db
do
  retx=$(basename $db | cut -d '_' -f 4)
  sqlite3 $db << EOF
.mode csv
.header off
SELECT 
  a.src,
  a.dest,
  $retx as retx,
  a.prr as rl,
  b.prr as lr
FROM prr_clean a
JOIN prr_clean b
  ON a.src=b.dest AND a.dest=b.src
WHERE a.dest=0 AND a.pr=0 AND b.pr = 0;
EOF
done
