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
logTf=$tfb.log
rxTf=$tfb.rx
txTf=$tfb.tx
rTf=$tfb.r
rsTf=$tfb.rs
errTf=$tfb.err
settingsTf=$tfb.settings
synchLossTf=$tfb.synchLoss
synchRecoverTf=$tfb.synchRecover
lagTf=$tfb.lag
lpcTf=$tfb.lpc
rslbTf=$tfb.rslb

#TODO: would be smart to put this in ramdisk
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

#set -x 
echo "extracting RX"
#1             2  3  4  5 6  7     8   9 10 11 12 13 14 15  16 17
#1343662476.53 21 RX s: 0 d: 65535 sn: 0 o: 0  c: 1  r: -55 l: 0
#pv $logFile | awk '($3 == "RX"){print $1,$5,$2,$7,$9,$11,$13,$15,$17,1}' > $rxTf
pv $logTf | awk '($3 == "RX" && NF == 17){print $1, $5, $2, $7, $9,$11,$13,$15,$17,1}' > $rxTf

echo "extracting TX"
#1      2 3  4  5 6  7     8   9 10  11 12 13 14 15 16 17 18 19   20 21
#1...71 0 TX s: 0 d: 65535 sn: 0 ofn: 0 np: 1 pr: 0 tp: 1 am: 224 e: 0
pv $logTf | awk '($3 == "TX" && NF == 21){print $1,$5,$7,$9, $11, $13, $15, $17, $19, $21}' > $txTf

echo "extracting routing decisions"
#1             2 3   4  5  6  7 8   9 10 11 12 13 14 15 16 17 18 19
#1344892228.29 3 UBF s: 31 d: 0 sn: 0 sm: 4 md: 4 sd: 3 bw: 0 f: 0
pv $logTf | awk '($3 == "UBF" && NF == 19){print $1, $2, $5, $7, $9, $11, $13, $15, $17, $19}' > $rTf

echo "extracting errors"
pv $logTf | grep '!\[' | tr '[\->]!' ' ' | tr -s ' ' | awk '{print $1, $2, $3, $4}' > $errTf

echo "extracting radio stats"
#1      2 3  4 5 6 7
#123.45 1 RS 1 o 0 30820181
pv $logTf | awk '($3 == "LB"){curSlot[$2] = $5}($3 == "RS"){ 
  if ($2 in curSlot){
    cs=curSlot[$2]
  }else{
    cs=0
  }
  print $1, $2, $4, $5, ($6)*(2**32) + $7, cs
}' > $rsTf

echo "extracting test settings"
pv $logTf | grep ' 0 START ' | tr '_' ' ' | awk '{
  for (i=4; i <= NF; i+=2){
    print $1, $i, $(i+1)
  }
}' > $settingsTf

echo "extracting synch-losses"

pv $logTf | awk '/Started./{
  firstStart[$2] = $1
}
/start listen/{ 
  if (firstStart[$2] > 0 && nextStart[$2] == 0){
    print $2, $1
  }
}
/START/{
  if (firstStart[$2] > 0){
    nextStart[$2] = $1
  }
}' > $synchLossTf

pv $logTf | awk '/LPC/{print $1, $2, $4}' \
  > $lpcTf
pv $logTf | awk '/LAG/{print $1, $2, $4}' \
  > $lagTf

pv $logTf | awk '/Fast resynch/{
  print $2, $1
}' > $synchRecoverTf

touch $rslbTf
pv $logTf | awk '($3 == "LB"){print $1, $2, $4, $5}' > $rslbTf

if [ $(grep -c 'testLabel' < $settingsTf) -ne 1 ]
then
  echo "WARNING: expected 1 test label line found $(grep -c 'testLabel' < $settingsTf)" 1>&2
fi

sqlite3 $db << EOF
.headers OFF
.separator ' '

SELECT load_extension('/home/carlson/local/bin/libsqlitefunctions.so');

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
  f  INTEGER
);

select "Importing routing decisions";
.import $rTf ROUTES

select "Aggregating depth info";
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

select "Finding node startups";
DROP TABLE IF EXISTS FIRST_RX;
CREATE TABLE FIRST_RX AS
SELECT RX_ALL.* 
FROM RX_ALL 
JOIN (SELECT src, dest, min(ts) as fts FROM RX_ALL WHERE src=0 GROUP BY dest) frx
ON frx.dest = RX_ALL.dest 
   AND frx.src = RX_ALL.src 
   AND frx.fts = RX_ALL.ts;

select "Finding good data periods";
--Some NSLUs have serious lag in printing: nslu15 (nodes 22 and 23)
-- seems to report events up to ~60s late in some cases. 
DROP TABLE IF EXISTS PRR_BOUNDS;
CREATE TABLE PRR_BOUNDS AS
SELECT first_rx.dest as node,
  first_rx.ts - 60 as startTS,
  coalesce(error_events.ts, (SELECT max(ts) FROM TX_ALL)) - 60 as endTS
FROM first_rx 
LEFT JOIN error_events 
ON error_events.node = first_rx.dest;

--deal with root node
INSERT INTO PRR_BOUNDS (node, startTS, endTS) VALUES (0, 0, (select max(ts) from TX_ALL where src=0));

select "computing cleaned prr";
DROP TABLE IF EXISTS PRR_CLEAN;
CREATE TABLE PRR_CLEAN AS 
SELECT
  TX_ALL.src as src,
  RX_AND_MISSING.dest as dest,
  TX_ALL.tp as tp,
  TX_ALL.np as np,
  TX_ALL.pr as pr,
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
WHERE TX_ALL.ts >= PRR_BOUNDS.startTS
  AND TX_ALL.ts <= PRR_BOUNDS.endTS
GROUP BY TX_ALL.src,
  RX_AND_MISSING.dest,
  TX_ALL.tp,
  TX_ALL.np,
  TX_ALL.pr
ORDER BY prr;

-- DROP TABLE IF EXISTS PRR_NO_STARTUP;
-- CREATE TABLE PRR_NO_STARTUP AS 
-- SELECT
--   TX_ALL.src as src,
--   RX_AND_MISSING.dest as dest,
--   TX_ALL.tp as tp,
--   TX_ALL.np as np,
--   TX_ALL.pr as pr,
--   avg(RX_AND_MISSING.received) as prr
-- FROM TX_ALL
-- LEFT JOIN (
--   SELECT src, dest, sn, received FROM RX_ALL 
--   UNION 
--   SELECT src, dest, sn, 0 as received FROM MISSING_RX) RX_AND_MISSING ON
--   TX_ALL.src == RX_AND_MISSING.src AND
--   TX_ALL.sn == RX_AND_MISSING.sn 
-- LEFT JOIN error_events 
--   ON error_events.node == RX_AND_MISSING.dest
-- WHERE TX_ALL.ts >= (SELECT max(ts) from FIRST_RX)
--   AND TX_ALL.ts <= coalesce(error_events.ts, (select max(ts) from TX_ALL))
-- GROUP BY TX_ALL.src,
--   RX_AND_MISSING.dest,
--   TX_ALL.tp,
--   TX_ALL.np,
--   TX_ALL.pr
-- ORDER BY prr;

SELECT "Computing duty cycles";

SELECT "importing radio stat logs";
DROP TABLE IF EXISTS RADIO_STATS_RAW;
CREATE TABLE RADIO_STATS_RAW (
  ts REAL,
  node INTEGER,
  sn INTEGER,
  state TEXT,
  total INTEGER,
  slot INTEGER);

.import $rsTf RADIO_STATS_RAW

DROP TABLE IF EXISTS ACTIVE_STATES;
CREATE TABLE ACTIVE_STATES (
  state TEXT);
INSERT INTO ACTIVE_STATES (state) values ('f');
INSERT INTO ACTIVE_STATES (state) values ('r');
INSERT INTO ACTIVE_STATES (state) values ('t');


select "fixing counter overflows";
--OK, apparently the overflow detection is messed up (an extra
--  rollover is added). Detect the case where a counter incremented by
--  more time than has elapsed according to testbed and register an
--  adjustment of -0x100000000 ticks to all succeeding measurements on
--  that counter
--  
-- So we find cases where the ticks recorded reflect that more time
-- has elapsed than timestamps indicate, compute how many rollovers
-- appear to have occurred (cast/+1 is because of a lack of ceil..),
-- and then use the rollover time in ticks to compensate.
DROP TABLE IF EXISTS radio_stats_adjustment;
CREATE TABLE radio_stats_adjustment
AS
  SELECT *, -4294967296 * (1 + cast ( (elapsedTicks-elapsedUnix)*(6.5e6)/4294967296 as
  integer)) as adjustment FROM (
    SELECT 
      l.node, 
      r.sn, 
      l.state, 
      (r.total-l.total)/(6.5e6) as elapsedTicks,
      r.ts-l.ts as elapsedUnix
    FROM radio_stats_raw l 
    JOIN radio_stats_raw r 
      ON l.node=r.node 
      AND l.state=r.state 
      AND l.sn +1 = r.sn
    WHERE (r.total - l.total)/(6.5e6) > (r.ts - l.ts + 30)
  ) x;

--Now accumulate the adjustments on the raw table.
DROP TABLE IF EXISTS radio_stats_adjusted;

CREATE TABLE radio_stats_adjusted AS
SELECT r.ts as ts, r.node as node, r.sn as sn, r.state as state, 
  r.slot as slot, r.total + coalesce(sum(adjustment),0) as total
FROM radio_stats_raw r
LEFT JOIN radio_stats_adjustment a
ON a.node=r.node and a.state = r.state 
AND a.sn <= r.sn
GROUP BY r.ts, r.node, r.sn, r.state, r.slot;

select "Computing slot radio deltas";
DROP TABLE IF EXISTS SLOT_STATE_DELTAS;
CREATE TABLE SLOT_STATE_DELTAS AS
SELECT l.ts, l.node, l.sn, r.slot, l.state, r.total - l.total as dt
FROM radio_stats_adjusted l
JOIN radio_stats_adjusted r on l.node=r.node and l.state = r.state and
l.sn+1 = r.sn
JOIN prr_bounds on l.node=prr_bounds.node
WHERE l.ts > prr_bounds.startTS  and r.ts <= prr_bounds.endTs
--WHERE l.node = 63
--limit 5;
;

select "Computing slot radio totals";
DROP TABLE IF EXISTS SLOT_STATE_TOTALS;
CREATE TABLE SLOT_STATE_TOTALS AS
SELECT node, slot, state, sum(dt) as total
FROM SLOT_STATE_DELTAS
GROUP BY node, slot, state;

-- SELECT "Computing slot totals";
-- DROP TABLE IF EXISTS SLOT_TOTALS;
-- CREATE TABLE SLOT_TOTALS AS
-- SELECT node, slot, sum(total)  as total
-- FROM SLOT_STATE_TOTALS
-- GROUP BY node, slot;

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

SELECT "Computing depth asymmetry";

DROP TABLE IF EXISTS BD_LINKS;
CREATE TEMPORARY TABLE BD_LINKS
AS 
  SELECT distinct src, dest FROM rx_all
  INTERSECT
  SELECT distinct dest, src FROM rx_all;

DELETE FROM BD_LINKS WHERE src <> 0;

DROP TABLE IF EXISTS DEPTH_ASYMMETRY;
CREATE TABLE DEPTH_ASYMMETRY as
SELECT
  rx_all.src as root, 
  rx_all.dest as leaf, 
  0 as lr,
  rx_all.sn,
  rx_all.depth
FROM BD_LINKS
JOIN rx_all
  ON rx_all.src= bd_links.src and rx_all.dest = bd_links.dest
JOIN tx_all 
  ON rx_all.src=tx_all.src
    AND rx_all.sn = tx_all.sn
WHERE rx_all.src=0
  AND tx_all.np = 1
  AND tx_all.pr = 0;

INSERT INTO DEPTH_ASYMMETRY 
SELECT
  rx_all.dest as root, 
  rx_all.src as leaf, 
  1 as lr,
  rx_all.sn,
  rx_all.depth
FROM BD_LINKS
JOIN rx_all
  ON rx_all.src = bd_links.dest and rx_all.dest = bd_links.src
JOIN tx_all 
  ON rx_all.src=tx_all.src
    AND rx_all.sn = tx_all.sn
WHERE rx_all.dest = 0
  AND tx_all.np = 1
  AND tx_all.pr = 0;

--
DROP TABLE IF EXISTS IPI;
CREATE TABLE IPI AS 
SELECT src as node,
  (max(ts)-min(ts))/count(*) as ipi
FROM TX_ALL
WHERE am != 0
GROUP BY src;

DROP TABLE IF EXISTS TEST_SETTINGS;
CREATE TABLE TEST_SETTINGS (
  ts REAL,
  k  TEXT,
  v  TEXT
);
.import $settingsTf TEST_SETTINGS

DROP TABLE IF EXISTS SYNCH_LOSS;
CREATE TABLE SYNCH_LOSS (
  node INTEGER,
  ts REAL);

.import $synchLossTf SYNCH_LOSS

DROP TABLE IF EXISTS SYNCH_RECOVER;
CREATE TABLE SYNCH_RECOVER (
  node INTEGER,
  ts REAL);

.import $synchRecoverTf SYNCH_RECOVER

DROP TABLE IF EXISTS LPC;
CREATE TABLE LPC (
  ts REAL,
  node INTEGER,
  lpc INTEGER);

.import $lpcTf LPC

DROP TABLE IF EXISTS LAG;
CREATE TABLE LAG (
  ts REAL,
  node INTEGER,
  lag INTEGER);

.import $lagTf LAG

SELECT "organizing transmissions by burst";
-- organize transmissions by burst: number bursts by schedule sn
DROP TABLE IF EXISTS BURST_TX_ALL;
CREATE TABLE BURST_TX_ALL AS 
select tx_all.*, c.sn as burstNum
  from tx_all 
  join (
    select l.sn, l.ts as startTS, r.ts as endTS 
    from tx_all l 
    join tx_all r on l.src=0 and r.src=0 and r.sn=l.sn+1
  ) as c on ts between startTS and endTS 
;

SELECT "Computing interpacket spacing";
-- compute the spacing (in frames) between transmissions.
--  actualIPD is the actual measured value, ipd limits this to the
--  diameter of the network (e.g. for the case where we set the max
--  depth too conservatively)
DROP TABLE IF EXISTS BURST_SPACING;
CREATE TABLE BURST_SPACING AS 
SELECT l.*, 
  r.ofn-l.ofn as actualIPD, min(r.ofn-l.ofn, max_network_depth.d) as ipd,
  max_network_depth.d as floodIPD

FROM BURST_TX_ALL l
JOIN BURST_TX_ALL r
ON l.sn + 1 = r.sn AND l.src = r.src AND l.burstNum = r.burstNum
JOIN 
(select max(depth) as d from rx_all) as max_network_depth
;

EOF

if [ "$keepTemp" != "-k" ]
then
  rm $rxTf
  rm $txTf
  rm $tfb
  rm $rTf
  rm $rsTf
  rm $errTf
  rm $settingsTf
  rm $synchLossTf
  rm $synchRecoverTf
  rm $lagTf
  rm $lpcTf
  rm $rslbTf
  rm $logTf
else
  echo "keeping temp files"
fi
#  | awk --assign n=$nodeId '($2==n){print $0}' | tr ' ' '\t'
