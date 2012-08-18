#!/bin/bash
echo "src,dest,retx,prr_lr"
for db in db/nsfb_ub_all_*_0.db
do
  retx=$(basename $db | cut -d '_' -f 4)
  sqlite3 $db << EOF
.mode csv
.header off
SELECT 
  a.src,
  a.dest,
  $retx as retx,
  a.prr as lr
FROM prr a
WHERE a.dest=0 AND a.pr=1;
EOF
done

