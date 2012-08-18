#!/bin/bash
echo "src,dest,retx,prr_rl,prr_lr"
for db in db/nsfb_f_all_*_0.db
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
FROM prr a
JOIN prr b
  ON a.src=b.dest AND a.dest=b.src
WHERE a.dest=0 AND a.pr=0 AND b.pr = 0;
EOF
done
