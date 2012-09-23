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
db=$label
tfDir=tmp
mkdir -p $tfDir
mkdir -p $(dirname $db)

rootId=0

tickLen="4/26e6"

#dos2unix $logFile

#depthTf=$(tempfile -d $tfDir)
tfb=$(tempfile -d $tfDir)
#tfb=tmp/tmp
cycleTf=$tfb.cycle
rxTf=$tfb.rx
txTf=$tfb.tx
fwdTf=$tfb.fwd


if [ $(file $logFile | grep -c 'CRLF') -eq 1 ]
then
  echo "convert line endings"
  dos2unix $logFile
else 
  echo "skip convert line endings"
fi
# 1  2  3  4  5   6  7  8
# ts id SD np src sn hc fn
echo "Numbering cycles"
# when root transmits at frame 0, set cycle number to root SN
pv $logFile | awk --assign rootId=$rootId '
BEGIN{
  cycleStart=0
  cycleEnd=0
}
($2 == rootId && 
  ($3 == "SD" && $5 == 0 && $8 == 0)){
  cycleStart = cycleEnd
  cycleEnd = $1 - 1.0
  cycle = $6
  printf("%d %.02f %.02f\n", cycle, cycleStart, cycleEnd)
}' > $cycleTf

echo "Extracting receives"
pv $logFile | awk '($3 == "RD"){print $1, $2, $4, $5, $6, $7, $8}' >  $rxTf
echo "Extracting transmits"
pv $logFile | awk '($3 == "SD"){print $1, $2, $4, $5, $6, $7, $8}' >  $txTf
echo "Extracting forwarding decisions"
pv $logFile | awk '($3 == "UBF"){print $1, $2, $5, $7, $9, $11, $13, $15, $17, $19}' > $fwdTf

sqlite3 $db <<EOF
select "loading raw tx";
.separator ' '
DROP TABLE IF EXISTS link_tx_raw;
CREATE TABLE link_tx_raw (
  ts REAL,
  sender INTEGER,
  np INTEGER,
  src INTEGER,
  sn INTEGER,
  hc INTEGER,
  fn INTEGER
);
.import $txTf link_tx_raw

select "loading raw rx";
DROP TABLE IF EXISTS link_rx_raw;
CREATE TABLE link_rx_raw (
  ts REAL,
  receiver INTEGER,
  np INTEGER,
  src INTEGER,
  sn INTEGER,
  hc INTEGER,
  fn INTEGER
);
.import $rxTf link_rx_raw

select "loading raw forwarding decisions";
DROP TABLE IF EXISTS fwd_raw;
CREATE TABLE fwd_raw (
  ts REAL,
  node INTEGER,
  src INTEGER,
  dest INTEGER,
  sn INTEGER,
  sm INTEGER,
  md INTEGER,
  sd INTEGER,
  bw INTEGER,
  f INTEGER
);
.import $fwdTf fwd_raw

select "loading cycle numbers";
DROP TABLE IF EXISTS cycle;
CREATE TABLE cycle (
  cn INTEGER,
  startTS REAL,
  endTS REAL
);
.import $cycleTf cycle

select "numbering tx";
DROP TABLE IF EXISTS link_tx;
CREATE TABLE link_tx 
AS
SELECT cycle.cn as cn, link_tx_raw.*
FROM link_tx_raw
JOIN cycle
ON link_tx_raw.ts between cycle.startTS and cycle.endTS;

select "numbering rx";
DROP TABLE IF EXISTS link_rx;
CREATE TABLE link_rx 
AS
SELECT cycle.cn as cn, link_rx_raw.*
FROM link_rx_raw
JOIN cycle
ON link_rx_raw.ts between cycle.startTS and cycle.endTS;

SELECT "Numbering forwarding decisions";
DROP TABLE IF EXISTS fwd;
CREATE TABLE fwd as
SELECT cycle.cn as cn, fwd_raw.*
FROM fwd_raw
JOIN cycle
ON fwd_raw.ts between cycle.startTS and cycle.endTS;

select "counting conflicts";
DROP TABLE IF EXISTS distinct_tx;
CREATE TABLE distinct_tx as 
SELECT cn, fn, count(*) numDistinct
FROM (
SELECT distinct cn, fn, hc, src, sn
FROM link_tx 
) d
GROUP BY cn, fn;

select "finding losses";
DROP table if exists rx_outcomes;
CREATE TABLE rx_outcomes as
SELECT t.cn as cn, t.src as src, t.sn as sn, nodes.node as node, coalesce(received, 0) as received 
FROM (select * from link_tx where src=sender) t 
JOIN (select 0 as node ) nodes
LEFT JOIN (select distinct src, sn, receiver, 1 as received from link_rx) r 
ON t.src=r.src  and t.sn = r.sn
and nodes.node = r.receiver and r.receiver == 0;

DROP TABLE IF EXISTS tx_limits;
CREATE TABLE tx_limits as 
SELECT cn, src, min(sn), max(sn)
FROM link_tx
WHERE src=sender
GROUP BY cn, src;

--SELECT "num conflicts in $logFile" as label, count(*) FROM distinct_tx where numDistinct > 1;
DROP TABLE link_tx_raw;
DROP TABLE link_rx_raw;
EOF

if [ "-k" != "$keepTemp" ]
then
  rm $cycleTf
  rm $rxTf
  rm $txTf
  rm $fwdTf
fi
