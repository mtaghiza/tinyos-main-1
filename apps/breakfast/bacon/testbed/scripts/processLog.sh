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

tfb=$(tempfile -d $tfDir)
logTf=$tfb.log
schedTf=$tfb.sched
rxlTf=$tfb.rxl
txlTf=$tfb.txl
cflTf=$tfb.cf
fwlTf=$tfb.fwl
skewTf=$tfb.skew
settingsTf=$tfb.settings
rsTf=$tfb.rs
rrbTf=$tfb.rrb
atxTf=$tfb.atx
arxTf=$tfb.arx

if [ $(file $logFile | grep -c 'CRLF') -eq 1 ]
then
  echo "strip non-ascii characters"
  pv $logFile | tr -cd '\11\12\15\40-\176' > $logTf

  echo "convert line endings"
  dos2unix $logTf
else 
  echo "skip convert line endings"
  cp $logFile $logTf
fi

echo "extracting SCHED events"
# 1368558936.2  25   SCHED RX 241    1  802      11
# 1368558936.21 0    SCHED TX 241    1  802      802
# ts            node          sched# root sn csRemote csLocal
# 1             2             3      4    5  6        7
pv $logTf | grep ' SCHED ' | cut -d ' ' -f 3,4 --complement | awk '(NF == 7){print $0}' > $schedTf

echo "extracting RX_LOCAL events"
# 1368558911.19 43   NRX 0   0  894      2  916881 923320    65535 -79  1
# tsReport      node     src sn ofnLocal hc rx32k  report32k dest  rssi lqi
# 1             2        3   4  5        6  7      8         9     10   11
pv $logTf | grep ' NRX ' | cut -d ' ' -f 3 --complement | awk '(NF == 11){print $0}' > $rxlTf

echo "extracting network TX_LOCAL events"
# 1368558936.21 0   NTX 1  803      822299 829762    65535 2  0   196
# tsReport      src     sn ofnLocal tx32k  report32k dest  tp stp AMID
# 1             2       3  4        5      6         7     8  9   10
pv $logTf | grep ' NTX ' | cut -d ' ' -f 3 --complement | awk '(NF==10){print $0}'> $txlTf

echo "extracting CRCF_LOCAL events"
# 1368558910.98 4    CRCF 981
# ts            node      fnLocal
# 1             2         3
pv $logTf | grep ' CRCF ' | cut -d ' ' -f 3 --complement | awk '(NF==3){print $0}' > $cflTf

echo "extracting FW_LOCAL events"
# 1368558936.01 25   NFW 12       2
# ts            node     ofnLocal hc
# 1             2        3        4
pv $logTf | grep ' NFW ' | cut -d ' ' -f 3 --complement | awk '(NF==4){print $0}' > $fwlTf

echo "extracting SKEW measurements"
# 1368558961.22 24   SK TPF_s: -8       ld: -12288 over  800
# ts            node           tpf*4096     delta(*4096) frames-since-last
# 1             2              3            4            5
pv $logTf | grep ' SK TPF_s: ' | cut -d ' ' -f 3,4,6,8 --complement  | awk '(NF == 5){print $0}' > $skewTf

echo "extracting settings"
pv $logTf | grep ' START ' | cut -d ' ' -f 3 --complement | awk '{ts=$1; node=$2; for (i=3; i<= NF; i++){ print ts, node, $i}}' | tr '=' ' ' > $settingsTf

echo "extracting radio stats"
pv $logTf | grep -e ' LB ' -e ' RS ' | awk '($3 == "LB" && NF == 5){
  curSlot[$2] = $5
}
($3 == "RS" && NF == 6){ 
  if ($2 in curSlot){
    cs=curSlot[$2]
  }else{
    cs=0
  }
  print $1, $2, $4, $5, $6, cs
}' > $rsTf

echo "Extracting forwarding decisions"
# 1370134164.75 38 RRB 32 0    640 3  2  2  0  0
# ts            fwd   src dest sn  sm md sd bw f
# 1             2     3   4    5   6  7  8  9  10 
pv $logTf | grep ' RRB ' | cut -d ' ' -f 3 --complement | awk '(NF == 10){print $0}' > $rrbTf

echo "Extracting APP level TX"
#1370010253.87 1   APP TXD 0  to 0    0   Q 2
#ts            src         sn    dest err   queue occupancy
#1             2           3     4    5     6
pv $logTf | grep ' APP TXD ' | cut -d ' ' -f 3,4,6,9 --complement  | awk '(NF == 6){print $0}' > $atxTf

echo "Extracting APP level RX"
#1370010253.62 0    APP RX 1   0
#ts            dest        src sn
#1             2           3   4

pv $logTf | grep ' APP RX ' | cut -d ' ' -f 3,4 --complement | awk '(NF == 4){print $0}' > $arxTf

sqlite3 $db << EOF
.headers OFF
.separator ' '

--for stdev computation
SELECT load_extension('/home/carlson/local/bin/libsqlitefunctions.so');

DROP TABLE IF EXISTS SCHED_TMP;
CREATE TEMPORARY TABLE SCHED_TMP (
  ts REAL,
  node INTEGER,
  schedNum INTEGER,
  src INTEGER,
  sn INTEGER,
  csRemote INTEGER,
  csLocal INTEGER);

SELECT "Importing SCHED";
.import $schedTf SCHED_TMP

SELECT "Ordering SCHED";
DROP TABLE IF EXISTS SCHED;
CREATE TABLE SCHED AS 
  SELECT * FROM SCHED_TMP ORDER BY node, ts;

SELECT "Indexing SCHED";
DROP INDEX IF EXISTS sched_index;
CREATE INDEX sched_index ON SCHED (node, csLocal);

SELECT "Creating SCHED_RANGE table";
DROP TABLE IF EXISTS SCHED_RANGE;
CREATE TABLE SCHED_RANGE AS
  SELECT l.node, l.schedNum, l.sn as cycleNum, l.csRemote, l.csLocal, 
    r.csLocal as csNext
  FROM SCHED l
    JOIN SCHED r ON l.rowid + 1 == r.rowid AND l.node == r.node;

SELECT "Indexing SCHED_RANGE table";
DROP INDEX IF EXISTS sched_range;
CREATE INDEX sched_range_index ON sched_range (node, csLocal, csNext);

DROP TABLE IF EXISTS RX_LOCAL;
CREATE TABLE RX_LOCAL (
  reportTs REAL,
  dest INTEGER,
  src INTEGER,
  sn INTEGER,
  ofnLocal INTEGER,
  depth INTEGER,
  rx32k INTEGER,
  report32k INTEGER,
  pdest INTEGER,
  rssi INTEGER,
  lqi INTEGER);

SELECT "Importing RX_LOCAL";
.import $rxlTf RX_LOCAL

SELECT "Mapping RX_LOCAL to RX_ALL";
DROP TABLE IF EXISTS RX_ALL;
CREATE TABLE RX_ALL AS
SELECT RX_LOCAL.*, 
  ofnLocal-csLocal + depth-1 as fnCycle, 
  ofnLocal-csLocal + csRemote + depth-1 as fnGlobal,
  cycleNum,
  1 as received
FROM RX_LOCAL
JOIN sched_range as s 
ON RX_LOCAL.dest == s.node 
  AND RX_LOCAL.ofnLocal BETWEEN s.csLocal and s.csNext ;

SELECT "Indexing RX_ALL";
DROP INDEX IF EXISTS rx_all_index;
CREATE INDEX rx_all_index ON rx_all (dest, ofnLocal);


DROP TABLE IF EXISTS TX_LOCAL;
CREATE TABLE TX_LOCAL (
  reportTs REAL,
  src INTEGER,
  sn INTEGER,
  ofnLocal INTEGER,
  tx32k INTEGER,
  report32k INTEGER,
  dest INTEGER,
  tp INTEGER,
  stp INTEGER,
  amId INTEGER);

SELECT "Importing TX_LOCAL";
.import $txlTf TX_LOCAL

SELECT "Mapping TX_LOCAL to TX_ALL";
DROP TABLE IF EXISTS TX_ALL;
-- Join each TX_LOCAL record with preceding SCHED and put in
-- standardized cycle-local and global frame numbers, as well as
-- cycle number.
CREATE TABLE TX_ALL AS
SELECT TX_LOCAL.*, 
  ofnLocal-csLocal as fnCycle, 
  ofnLocal-csLocal + csRemote as fnGlobal,
  cycleNum
FROM TX_LOCAL
JOIN SCHED_RANGE as s
ON TX_LOCAL.src == s.node 
  AND TX_LOCAL.ofnLocal BETWEEN s.csLocal and s.csNext ;

SELECT "Indexing TX_ALL";
DROP INDEX IF EXISTS tx_all_index;
CREATE INDEX tx_all_index ON tx_all (src, ofnLocal);

DROP TABLE IF EXISTS FW_LOCAL;
CREATE TABLE FW_LOCAL (
  ts REAL,
  node INTEGER,
  ofnLocal INTEGER,
  depth INTEGER);

SELECT "Importing FW_LOCAL";
.import $fwlTf  FW_LOCAL

SELECT "Mapping FW_LOCAL to FW_ALL";
DROP TABLE IF EXISTS FW_ALL;
CREATE TABLE FW_ALL AS
SELECT FW_LOCAL.*, 
  orig.src as src, orig.sn as sn,
  fw_local.ofnLocal-csLocal + depth-1 as fnCycle, 
  fw_local.ofnLocal-csLocal + csRemote + depth-1 as fnGlobal,
  cycleNum
FROM FW_LOCAL
JOIN SCHED_RANGE as s
ON FW_LOCAL.node == s.node 
  AND FW_LOCAL.ofnLocal BETWEEN s.csLocal and s.csNext 
JOIN ( 
  SELECT RX_ALL.ofnLocal as ofnLocal, RX_ALL.src as src, RX_ALL.dest as node, RX_ALL.sn as sn FROM RX_ALL
  UNION SELECT TX_ALL.ofnLocal, TX_ALL.src, TX_ALL.src, TX_ALL.sn FROM TX_ALL) orig
ON orig.node == fw_local.node AND orig.ofnLocal == fw_local.ofnLocal
WHERE FW_LOCAL.depth > 1
;


DROP TABLE IF EXISTS CRCF_LOCAL;
CREATE TABLE CRCF_LOCAL (
  ts REAL,
  node INTEGER,
  fnLocal INTEGER);

SELECT "Importing CRCF_LOCAL";
.import $cflTf CRCF_LOCAL

SELECT "Mapping CRCF_LOCAL to CRCF_ALL";
DROP TABLE IF EXISTS CRCF_ALL;
CREATE TABLE CRCF_ALL AS
SELECT CRCF_LOCAL.*, 
  CRCF_LOCAL.fnLocal-csLocal as fnCycle, 
  CRCF_LOCAL.fnLocal-csLocal + csRemote as fnGlobal,
  cycleNum
FROM CRCF_LOCAL
JOIN (
  SELECT l.node, l.schedNum, l.sn as cycleNum, l.csRemote, l.csLocal, 
    r.csLocal as csNext
  FROM SCHED l
    JOIN SCHED r ON l.rowid + 1 == r.rowid AND l.node == r.node) as s
ON CRCF_LOCAL.fnLocal BETWEEN s.csLocal and s.csNext 
  AND CRCF_LOCAL.node == s.node 
;

SELECT "Aggregating depth info";
DROP TABLE IF EXISTS AGG_DEPTH;
CREATE TABLE AGG_DEPTH AS 
SELECT src,
  dest,
  min(depth) as minDepth,
  max(depth) as maxDepth,
  avg(depth) as avgDepth,
  stdev(depth) as sdDepth,
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

select "Computing Raw PRRs";
DROP TABLE IF EXISTS PRR;
CREATE TABLE PRR AS 
SELECT
  TX_ALL.src as src,
  RX_AND_MISSING.dest as dest,
  TX_ALL.tp as tp,
  TX_ALL.stp as stp,
  avg(RX_AND_MISSING.received) as prr,
  count(RX_AND_MISSING.received) as cnt
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
  TX_ALL.stp
ORDER BY prr;

DROP TABLE IF EXISTS SKEW;
CREATE TABLE SKEW (
  ts REAL,
  node INTEGER,
  tpf INTEGER,
  lastDelta INTEGER,
  lastPeriod INTEGER
);

SELECT "importing SKEW measurements";
.import $skewTf SKEW

SELECT "Aggregating SKEW measurements";
DROP TABLE IF EXISTS AGG_SKEW;
CREATE TABLE AGG_SKEW AS
SELECT node, avg(tpf) as tpf
FROM SKEW
GROUP BY node;

DROP TABLE IF EXISTS TEST_SETTINGS;
CREATE TABLE TEST_SETTINGS (
  ts REAL,
  node INTEGER,
  k TEXT,
  v TEXT);


SELECT "importing settings";
.import $settingsTf TEST_SETTINGS

SELECT "Setting PRR boundaries";
DROP TABLE IF EXISTS PRR_BOUNDS;
CREATE TABLE PRR_BOUNDS AS 
SELECT node, min(ts) as startTS, max(ts) as endTS
FROM SCHED 
GROUP BY node;

select "computing cleaned prr";
DROP TABLE IF EXISTS PRR_CLEAN;
CREATE TABLE PRR_CLEAN AS 
SELECT
  TX_ALL.src as src,
  RX_AND_MISSING.dest as dest,
  TX_ALL.tp as tp,
  TX_ALL.stp as stp,
  avg(RX_AND_MISSING.received) as prr,
  count(RX_AND_MISSING.received) as cnt
FROM TX_ALL
LEFT JOIN (
  SELECT src, dest, sn, received FROM RX_ALL 
  UNION 
  SELECT src, dest, sn, 0 as received FROM MISSING_RX) RX_AND_MISSING ON
  TX_ALL.src == RX_AND_MISSING.src AND
  TX_ALL.sn == RX_AND_MISSING.sn 
JOIN PRR_BOUNDS ON PRR_BOUNDS.node = RX_AND_MISSING.dest
WHERE TX_ALL.reportTs >= PRR_BOUNDS.startTS
  AND TX_ALL.reportTs <= PRR_BOUNDS.endTS
GROUP BY TX_ALL.src,
  RX_AND_MISSING.dest,
  TX_ALL.tp,
  TX_ALL.stp
ORDER BY prr;

SELECT "Importing APP level TX";
DROP TABLE IF EXISTS APP_TX;
CREATE TABLE APP_TX (
  ts REAL, 
  src INTEGER,
  sn INTEGER,
  dest INTEGER,
  error INTEGER,
  queue INTEGER);
.import $atxTf APP_TX

SELECT "Importing APP level RX";
DROP TABLE IF EXISTS APP_RX;
CREATE TABLE APP_RX (
  ts REAL, 
  dest INTEGER,
  src INTEGER,
  sn INTEGER);
.import $arxTf APP_RX

SELECT "adding schedule rx to APP RX";
INSERT INTO APP_RX 
SELECT ts, node, src, sn FROM SCHED
WHERE src != node;

SELECT "adding schedule tx to APP TX";
INSERT INTO APP_TX
SELECT ts, src, sn, 65535, 0, -1 FROM SCHED
WHERE src == node;

select "Finding missing APP receptions";
DROP TABLE IF EXISTS MISSING_APP_RX;
CREATE TABLE MISSING_APP_RX AS
SELECT APP_TX.src, 
  nodes.dest, 
  APP_TX.sn
FROM APP_TX
  JOIN (SELECT DISTINCT APP_RX.dest FROM APP_RX) nodes 
  ON APP_TX.dest == nodes.dest 
     OR (APP_TX.dest == 65535 AND APP_TX.src != nodes.dest)
EXCEPT SELECT APP_RX.src, APP_RX.dest, APP_RX.sn FROM APP_RX;

select "Finding APP PRR";
DROP TABLE IF EXISTS APP_PRR;
CREATE TABLE APP_PRR AS
SELECT
  APP_TX.src as src,
  RX_AND_MISSING.dest as dest,
  avg(RX_AND_MISSING.received) as prr,
  count(RX_AND_MISSING.received) as cnt
FROM APP_TX
LEFT JOIN (
  SELECT src, dest, sn, 1 as received FROM APP_RX 
  UNION 
  SELECT src, dest, sn, 0 as received FROM MISSING_APP_RX) RX_AND_MISSING ON
  APP_TX.src == RX_AND_MISSING.src AND
  APP_TX.sn == RX_AND_MISSING.sn 
JOIN PRR_BOUNDS 
  ON RX_AND_MISSING.dest == PRR_BOUNDS.node
WHERE APP_TX.error == 0
  AND APP_TX.ts between PRR_BOUNDS.startTS and PRR_BOUNDS.endTS
GROUP BY APP_TX.src,
  RX_AND_MISSING.dest
ORDER BY prr;


SELECT "importing radio stats";
DROP TABLE IF EXISTS RADIO_STATS_RAW;
CREATE TABLE RADIO_STATS_RAW (
  ts REAL,
  node INTEGER,
  sn INTEGER,
  state TEXT,
  total INTEGER,
  slot INTEGER
);

.import $rsTf RADIO_STATS_RAW

DROP TABLE IF EXISTS ACTIVE_STATES;
CREATE TABLE ACTIVE_STATES (
  state TEXT);
INSERT INTO ACTIVE_STATES (state) values ('f');
INSERT INTO ACTIVE_STATES (state) values ('r');
INSERT INTO ACTIVE_STATES (state) values ('t');

select "Computing slot radio deltas";
DROP TABLE IF EXISTS SLOT_STATE_DELTAS;
CREATE TABLE SLOT_STATE_DELTAS AS
SELECT l.ts, l.node, l.sn, r.slot, l.state, r.total - l.total as dt
FROM radio_stats_raw l
JOIN radio_stats_raw r on l.node=r.node and l.state = r.state and
l.sn+1 = r.sn
JOIN prr_bounds on l.node=prr_bounds.node
WHERE l.ts > prr_bounds.startTS  and r.ts <= prr_bounds.endTs ;

select "Computing slot radio totals";
DROP TABLE IF EXISTS SLOT_STATE_TOTALS;
CREATE TABLE SLOT_STATE_TOTALS AS
SELECT node, slot, state, sum(dt) as total
FROM SLOT_STATE_DELTAS
GROUP BY node, slot, state;

SELECT "Computing node totals";
DROP TABLE IF EXISTS NODE_TOTALS;
CREATE TABLE NODE_TOTALS AS
SELECT node, state, sum(total) as total
FROM SLOT_STATE_TOTALS
GROUP BY node, state;

SELECT "Computing overall duty cycle";
DROP TABLE IF EXISTS DUTY_CYCLE;
CREATE TABLE DUTY_CYCLE AS 
SELECT active.node, (1.0*active.total)/allStates.total as dc
FROM (
  SELECT node, sum(total) as total FROM node_totals where state in
  (select state from active_states) group by node) active
JOIN (
  SELECT node, sum(total) as total FROM node_totals group by node)
  allStates on active.node=allStates.node;

SELECT "Computing dc contribution per slot";
DROP TABLE IF EXISTS SLOT_CONTRIBUTIONS;

CREATE TABLE SLOT_CONTRIBUTIONS AS 
SELECT activeSlot.node, activeSlot.slot,
  (1.0*activeSlot.total)/activeNode.total as fractionActive
FROM 
(
  SELECT node, slot, sum(total) as total
  FROM SLOT_STATE_TOTALS
  WHERE state in (select state from active_states)
  GROUP BY node, slot 
) as activeSlot
JOIN (
  SELECT node, sum(total) as total
  FROM node_totals
  WHERE state in (select state from active_states)
  GROUP BY node
) as activeNode 
on activeSlot.node=activeNode.node;



SELECT "ERROR_EVENTS placecholder (empty)";
DROP TABLE IF EXISTS ERROR_EVENTS;
CREATE TABLE ERROR_EVENTS (
  ts REAL,
  node INTEGER,
  fromState TEXT,
  toState TEXT
);

SELECT "Importing routing decisions";
DROP TABLE IF EXISTS ROUTES;
CREATE TABLE ROUTES (
  ts REAL,
  fwd INTEGER,
  src INTEGER,
  dest INTEGER,
  sn INTEGER,
  sm INTEGER,
  md INTEGER,
  sd INTEGER,
  bw INTEGER,
  f INTEGER);
.import $rrbTf ROUTES

SELECT "computing forwarder counts";
DROP TABLE IF EXISTS FWD_COUNT;
CREATE TABLE FWD_COUNT AS
SELECT 
  min(ts) as ts, src, dest, sn, sum(f) as cnt
FROM ROUTES
GROUP BY src, dest, sn;

EOF


if [ "$keepTemp" != "-k" ]
then
  rm $tfb
  rm $logTf
  rm $schedTf
  rm $rxlTf
  rm $txlTf
  rm $cflTf
  rm $fwlTf
  rm $skewTf
  rm $settingsTf
  rm $rsTf
  rm $rrbTf
  rm $atxTf
  rm $arxTf
fi
