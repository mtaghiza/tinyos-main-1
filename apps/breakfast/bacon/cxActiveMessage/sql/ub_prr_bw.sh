#!/bin/bash
#TODO: paramterize db directory
echo "src,dest,bw,prr_lr"
for db in db/nsfb_ub_all_1_*.db
do
  bw=$(basename $db | cut -d '_' -f 5 | cut -d '.' -f 1)
  sqlite3 $db << EOF
.mode csv
.header off
SELECT 
  a.src,
  a.dest,
  $bw as bw,
  a.prr as lr
FROM prr a
WHERE a.dest=0 AND a.pr=1;
EOF
done

