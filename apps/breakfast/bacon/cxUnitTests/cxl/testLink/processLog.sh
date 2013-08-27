#!/bin/bash
if [ $# -lt 2 ]
then 
  echo "Usage: $0 <logFile> <dbFile>" 1>&2
  exit 1
fi
log=$1
db=$2

dos2unix $log

echo "Processing $log: RX"
#1             2  3  4   5  6 7  8    9  10   11
#ts            n  -  sn  hc t pl sfds pa minP maxP
#1377284263.55 32 RX 336 10 6 1  0    0  3    2d
pv $log | grep ' RX ' | awk '/^[0-9]*.[0-9]* [0-9]* RX [0-9]* [0-9]* [0-9]* [0-9]* [0-9]* [0-9]* [0-9a-f]* [0-9a-f]* [0-9]*$/{print $1, $2, $4, $5, $6, $7, $8, $9, $10, $11, $12, 1}' > rx.tmp

echo "Processing $log: TX"
#1             2  3  4   5 6  7    8  9   10  11
#ts            n  -  sn  e t  pl sfds pa minP maxP
#1377284976.97 0  TX 273 0 6  1    0  1  3    2d
pv $log | grep ' TX ' | awk '/^[0-9]*.[0-9]* [0-9]* TX [0-9]* [0-9]* [0-9]* [0-9]* [0-9]* [0-9]* [0-9a-f]* [0-9a-f]* [0-9]*$/{print $1, $2, $4, $6, $7, $8, $9, $10, $11, $12 }' > tx.tmp

echo "Processing $log: missed deadlines"
pv $log | grep -e ' TX ' -e 'RMD' -e 'SMD' | awk '/TX/{
  testNum=$6
}
/RMD/{
  print testNum, $2, $1, "R"
}
/SMD/{
  print testNum, $2, $1, "S"
}' > md.tmp

sqlite3 $db <<EOF
.separator ' '
drop table if exists RX;
CREATE TABLE RX (
  ts FLOAT,
  node INTEGER,
  sn INTEGER,
  hc INTEGER,
  tn INTEGER,
  pl INTEGER,
  sfds INTEGER,
  pa INTEGER,
  minP TEXT,
  maxP TEXT,
  flfs INTEGER,
  r INTEGER
);
SELECT "Loading RX";
.import 'rx.tmp' RX

drop table if exists TX;
CREATE TABLE TX (
  ts FLOAT,
  node INTEGER,
  sn INTEGER,
  tn INTEGER,
  pl INTEGER,
  sfds INTEGER,
  pa INTEGER,
  minP TEXT,
  maxP TEXT,
  flfs INTEGER
);
SELECT "Loading TX";
.import 'tx.tmp' TX

SELECT "Loading missed link deadlines";
DROP TABLE IF EXISTS MD;
CREATE TABLE MD (
  tn INTEGER,
  node INTEGER,
  ts FLOAT,
  t TEXT
);
.import 'md.tmp' MD

DROP TABLE IF EXISTS nodes;
CREATE TABLE nodes as 
SELECT distinct node from TX UNION
SELECT distinct node from RX;

DROP TABLE IF EXISTS setups;
CREATE TABLE setups AS
SELECT distinct tn, node as origin, pl, sfds, pa, minP, maxP, flfs FROM TX;

SELECT "Finding drops";
DROP TABLE IF EXISTS RXM;
CREATE TABLE RXM as
SELECT tx.tn, tx.sn, nodes.node, coalesce(rx.r, 0) as r
FROM TX 
JOIN nodes
LEFT JOIN rx ON tx.tn = rx.tn AND tx.sn = rx.sn AND rx.node = nodes.node;

SELECT "Finding duplicates";
DROP TABLE IF EXISTS rxc;
CREATE TABLE rxc AS
SELECT tn, node, sn, count(*) AS cnt
FROM rx
GROUP BY tn, node, sn;

SELECT "Aggregating node-results";
DROP TABLE IF EXISTS AGG;
CREATE TABLE AGG AS
SELECT prr.tn as tn, prr.node as node, prr.prr as prr, hopCount.avgHC
as hopCount, coalesce(dc.dc, 0) as dc
FROM 
(SELECT tn, node, (1.0*sum(r))/count(r) as prr FROM rxm GROUP BY tn,
node) prr
JOIN 
(SELECT tn, node, avg(hc) as avgHC FROM rx GROUP BY tn, node) hopCount
ON hopCount.tn = prr.tn AND hopCount.node = prr.node
LEFT JOIN (SELECT tn, node, count(*) as dc
FROM rxc
WHERE rxc.cnt>1 
GROUP BY tn, node) dc ON dc.tn= prr.tn and dc.node=prr.node;

SELECT "Aggregating test results";
DROP TABLE IF EXISTS agg_sum;
CREATE TABLE agg_sum AS
SELECT pl, sfds, pa, flfs, avg(prr) as prr, avg(dc) as dc, avg(sCnt)
as sCnt, avg(rCnt) as rCnt, hc as avgMaxHC
FROM (
  SELECT setups.tn, setups.pl, setups.sfds, setups.pa, setups.flfs,
  A.prr, coalesce(B.sCnt, 0) as sCnt, coalesce(C.rCnt, 0) as rCnt, hc,
  dc
  FROM setups JOIN (
    SELECT tn, avg(prr) as prr, avg(dc) as dc, max(hopCount) as hc FROM agg GROUP BY tn
  ) A ON a.tn=setups.tn
  left JOIN (
    SELECT tn, count(*) as sCnt 
    FROM md
    WHERE t = 'S'
    GROUP BY tn
  ) B ON A.tn = B.tn
  left JOIN (
    SELECT tn, count(*) as rCnt 
    FROM md
    WHERE t = 'R'
    GROUP BY tn
  ) C ON A.tn = C.tn
) X
GROUP BY pl, sfds, pa, flfs ORDER BY prr;

SELECT "Aggregating test results: omit problem nodes";
DROP TABLE IF EXISTS agg_sum_ok;
CREATE TABLE agg_sum_ok AS
SELECT pl, sfds, pa, flfs, avg(prr) as prr, avg(dc) as dc, avg(sCnt)
as sCnt, avg(rCnt) as rCnt, hc as avgMaxHC
FROM (
  SELECT setups.tn, setups.pl, setups.sfds, setups.pa, setups.flfs,
  A.prr, coalesce(B.sCnt, 0) as sCnt, coalesce(C.rCnt, 0) as rCnt, hc,
  dc
  FROM setups JOIN (
    SELECT tn, avg(prr) as prr, avg(dc) as dc, max(hopCount) as hc FROM agg 
    WHERE node not in (46, 47) GROUP BY tn
  ) A ON a.tn=setups.tn
  left JOIN (
    SELECT tn, count(*) as sCnt 
    FROM md
    WHERE t = 'S'
    GROUP BY tn
  ) B ON A.tn = B.tn
  left JOIN (
    SELECT tn, count(*) as rCnt 
    FROM md
    WHERE t = 'R'
    GROUP BY tn
  ) C ON A.tn = C.tn
) X
GROUP BY pl, sfds, pa, flfs ORDER BY prr;

EOF
