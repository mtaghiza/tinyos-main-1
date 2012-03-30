#!/bin/bash
if [ $# -lt 1 ]
then
  echo "Usage: $0 <logFile>"
  exit 1
fi
logFile=$1
db=$logFile.db
depthTf=$(tempfile)
rxTf=$(tempfile)
txTf=$(tempfile)
irTf=$(tempfile)
rTf=$(tempfile)
awk '($3 == "s" || $3 == "S"){print $1,$2,$4}' $logFile  > $depthTf
awk '($3 == "RX"){print $1,$5,$2,$7,$9,$11}' $logFile  > $rxTf
awk '($3 == "TX"){print $1,$5,$7,$9}' $logFile  > $txTf
awk '($3 == "R.ir"){print $1,$2,$4,$5}' $logFile > $irTf
awk '($3 == "R.r"){print $1,$2,$4,$5}' $logFile > $rTf

#TODO: also duty cycle output when available

sqlite3 $db << EOF
DROP TABLE IF EXISTS DEPTH;
CREATE TABLE DEPTH (
  ts REAL,
  node INTEGER,
  depth INTEGER
);
.separator ' '
.import $depthTf DEPTH

DROP TABLE IF EXISTS AGG_DEPTH;
CREATE TABLE AGG_DEPTH AS
SELECT node,
  min(depth) as minDepth, 
  max(depth) as maxDepth,
  avg(depth) as avgDepth,
  count(*) as cnt
FROM DEPTH
GROUP BY node
ORDER BY avgDepth;

DROP TABLE IF EXISTS TX;
CREATE TABLE TX (
  ts REAL,
  src INTEGER,
  dest INTEGER,
  sn INTEGER
);
.import $txTf TX

DROP TABLE IF EXISTS RX;
CREATE TABLE RX (
  ts REAL,
  src INTEGER,
  dest INTEGER,
  pDest INTEGER,
  sn INTEGER,
  depth INTEGER
);
.import $rxTf RX

DROP TABLE IF EXISTS CONN;
CREATE TABLE CONN AS 
  SELECT tx.ts as ts, 
    tx.src as src, 
    rx.dest as dest, 
    tx.dest as pDest,
    tx.sn as sn,
    rx.depth as depth,
    CASE
      WHEN rx.dest IS NULL THEN 0
      WHEN rx.dest IS NOT NULL THEN 1
    END as received
  FROM TX LEFT JOIN RX ON
    RX.src == TX.src AND
    RX.sn == TX.sn
  ORDER BY tx.ts
;

DROP TABLE IF EXISTS REQ;
CREATE TABLE REQ (
  ts REAL,
  node INTEGER,
  rm INTEGER,
  fn INTEGER
);
.import $irTf REQ

DROP TABLE IF EXISTS REL;
CREATE TABLE REL (
  ts REAL,
  node INTEGER,
  rm INTEGER,
  fn INTEGER
);
.import $rTf REL

--select * from AGG_DEPTH;
--select count(*) from AGG_DEPTH;
EOF
rm $depthTf
rm $rxTf
rm $txTf
rm $irTf
rm $rTf
#  | awk --assign n=$nodeId '($2==n){print $0}' | tr ' ' '\t'
