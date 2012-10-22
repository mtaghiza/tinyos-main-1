#!/bin/bash
if [ $# -lt 3 ]
then
  echo "Usage: $0 <log> <trace> <outputFile> [tsMin] [tsMax]" 1>&2
  exit 1
fi
set -x
log=$1
trace=$2
of=$3
tsMin=$4
tsMax=$5

tf=$(tempfile -d tmp)


if [ "$tsMin" == "" ]
then
  tsMin=$(head -1 $log | cut -d ' ' -f 1)
fi

if [ "$tsMax" == "" ]
then 
  tsMax=$(tail -1 $log | cut -d ' ' -f 1)
fi

awk -F ',' --assign tsMin=$tsMin --assign tsMax=$tsMax \
'(NR==1){
  print $0
} 
($1 >= tsMin && $1 <= tsMax ){
  print $0
}' $trace > $tf.trace

tail --lines=+2 $tf.trace \
  | python processing_scripts/synch.py \
  > $tf.edges

sqlite3 <<EOF > $of.csv
DROP TABLE IF EXISTS edge;

CREATE TABLE edge 
(ts REAL,
  pin INTEGER,
  re INTEGER);

.separator ','
.import $tf.edges edge

DROP TABLE IF EXISTS delta;

CREATE TABLE delta as
SELECT 
  l.ts as ts0, 
  r.ts as ts1, 
  l.rowid as r0, 
  r.rowid as r1, 
  r.ts - l.ts as delta
FROM edge as l 
  JOIN edge as r 
ON l.pin=6 AND r.pin=7 AND r.rowid = l.rowid+1
WHERE l.re=1 AND r.re =1;

.mode csv
SELECT ts0 - startTS.startTS as offset, 
  ts0 as absolute,
  delta,
  delta-avgDelta.avgDelta as dev
FROM delta
  JOIN (SELECT min(ts0) as startTS from delta) as startTS
  JOIN (SELECT avg(delta) as avgDelta from delta) as avgDelta;
EOF

scheds=""
for ts in $(grep ' 1 SCHED_SYNCH' $log | cut -d ' ' -f 1)
do
  scheds="$scheds -s $ts"
done

losses=""
for ts in $(grep ' 1 SYNCH_LOSS' $log | cut -d ' ' -f 1)
do
  losses="$losses -l $ts"
done

recovers=""
for ts in $(grep ' 1 FAST_RESYNCH' $log | cut -d ' ' -f 1)
do
  recovers="$recovers -r $ts"
done

cat <<EOF | tee $of.sh
R --args -f $of.csv \
  $scheds \
  $losses \
  $recovers
EOF
