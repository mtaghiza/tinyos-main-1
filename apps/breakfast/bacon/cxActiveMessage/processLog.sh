#!/bin/bash
if [ $# -lt 2 ]
then
  echo "Usage: $0 <logFile> <title> [-k]"
  echo "<logfile> the name to assign to the local copy of the log file"
  echo "-k: do not delete temp files after parsing log file"
  exit 1
fi
logFile=$1
label=$2
keepTemp=$3
db=$label.db
tfDir=tmp
mkdir -p $tfDir
mkdir -p $(dirname $db)

tickLen="4/26e6"

#dos2unix $logFile

#depthTf=$(tempfile -d $tfDir)
tfb=$(tempfile -d $tfDir)
#tfb=tmp/tmp
rxTf=$tfb.rx
txTf=$tfb.tx
errTf=$tfb.err

if [ $(file $logFile | grep -c 'CRLF') -eq 1 ]
then
  echo "convert line endings"
  dos2unix $logFile
else 
  echo "skip convert line endings"
fi

#set -x 
echo "extracting RX"
#1             2  3  4  5 6  7     8   9 10 11 12 13 14 15  16 17
#1343662476.53 21 RX s: 0 d: 65535 sn: 0 o: 0  c: 1  r: -55 l: 0
#pv $logFile | awk '($3 == "RX"){print $1,$5,$2,$7,$9,$11,$13,$15,$17,1}' > $rxTf
pv $logFile | awk '($3 == "RX"){print $1, $5, $2, $7, $9,$11,$13,$15,$17,1}' > $rxTf
echo "extracting TX"
#1      2 3  4  5 6  7     8   9 10  11 12 13 14 15 16 17 18 19   20 21
#1...71 0 TX s: 0 d: 65535 sn: 0 ofn: 0 np: 1 pr: 0 tp: 1 am: 224 e: 0
pv $logFile | awk '($3 == "TX"){print $1,$5,$7,$9, $11, $13, $15, $17, $19, $21}' > $txTf

echo "extracting errors"
pv $logFile | grep '!\[' | tr '[\->]!' ' ' | tr -s ' ' | awk '{print $1, $2, $3, $4}' > $errTf

sqlite3 $db << EOF
.headers OFF
.separator ' '

DROP TABLE IF EXISTS TX_ALL;
CREATE TABLE TX_ALL (
  ts REAL,
  src INTEGER,
  dest INTEGER,
  sn INTEGER,
  ofn INTEGER,
  np INTEGER,
  pr INTEGER,
  tp INTEGER,
  am INTEGER,
  err INTEGER
);
select "Importing TX_ALL from $txTf";
.import $txTf TX_ALL

DROP TABLE IF EXISTS RX_ALL;
CREATE TABLE RX_ALL (
  ts REAL,
  src INTEGER,
  dest INTEGER,
  pDest INTEGER,
  sn INTEGER,
  ofn INTEGER,
  depth INTEGER,
  rssi INTEGER,
  lqi INTEGER,
  received INTEGER
);
select "Importing RX_ALL from $rxTf";
.import $rxTf RX_ALL

--select "Removing non-root-involving receptions";
--DELETE FROM RX_ALL
--WHERE src !=0 and dest !=0;

DROP TABLE IF EXISTS ERROR_EVENTS;
CREATE TABLE ERROR_EVENTS (
  ts REAL,
  node INTEGER,
  fromState TEXT,
  toState TEXT
);

select "Importing error events";
.import $errTf ERROR_EVENTS

select "Aggregating depth info";
DROP TABLE IF EXISTS AGG_DEPTH;
CREATE TABLE AGG_DEPTH AS 
SELECT src,
  dest,
  min(depth) as minDepth,
  max(depth) as maxDepth,
  avg(depth) as avgDepth,
  count(*) as cnt
FROM RX_ALL
GROUP BY src, dest
ORDER BY avgDepth;

select "Finding missing receptions";
DROP TABLE IF EXISTS MISSING_RX;
CREATE TABLE MISSING_RX AS
SELECT TX_ALL.src, 
  nodes.dest, 
  TX_ALL.sn
FROM TX_ALL
  JOIN (SELECT DISTINCT RX_ALL.dest FROM RX_ALL) nodes 
  ON TX_ALL.dest == nodes.dest 
     OR (TX_ALL.dest == 65535 AND TX_ALL.src != nodes.dest)
EXCEPT SELECT RX_ALL.src, RX_ALL.dest, RX_ALL.sn FROM RX_ALL;

select "Computing PRRs";
DROP TABLE IF EXISTS PRR;
CREATE TABLE PRR AS 
SELECT
  TX_ALL.src as src,
  RX_AND_MISSING.dest as dest,
  TX_ALL.tp as tp,
  TX_ALL.np as np,
  TX_ALL.pr as pr,
  avg(RX_AND_MISSING.received) as prr
FROM TX_ALL
LEFT JOIN (
  SELECT src, dest, sn, received FROM RX_ALL 
  UNION 
  SELECT src, dest, sn, 0 as received FROM MISSING_RX) RX_AND_MISSING ON
  TX_ALL.src == RX_AND_MISSING.src AND
  TX_ALL.sn == RX_AND_MISSING.sn 
GROUP BY TX_ALL.src,
  RX_AND_MISSING.dest,
  TX_ALL.tp,
  TX_ALL.np,
  TX_ALL.pr
ORDER BY prr;

DROP TABLE IF EXISTS PRR_NO_STARTUP;
CREATE TABLE PRR_NO_STARTUP AS 
SELECT
  TX_ALL.src as src,
  RX_AND_MISSING.dest as dest,
  TX_ALL.tp as tp,
  TX_ALL.np as np,
  TX_ALL.pr as pr,
  avg(RX_AND_MISSING.received) as prr
FROM TX_ALL
LEFT JOIN (
  SELECT src, dest, sn, received FROM RX_ALL 
  UNION 
  SELECT src, dest, sn, 0 as received FROM MISSING_RX) RX_AND_MISSING ON
  TX_ALL.src == RX_AND_MISSING.src AND
  TX_ALL.sn == RX_AND_MISSING.sn 
WHERE TX_ALL.ts > 300+(SELECT min(ts) from TX_ALL)
GROUP BY TX_ALL.src,
  RX_AND_MISSING.dest,
  TX_ALL.tp,
  TX_ALL.np,
  TX_ALL.pr
ORDER BY prr;
EOF

if [ "$keepTemp" != "-k" ]
then
  rm $rxTf
  rm $txTf
  rm $tfb
else
  echo "keeping temp files"
fi
#  | awk --assign n=$nodeId '($2==n){print $0}' | tr ' ' '\t'
