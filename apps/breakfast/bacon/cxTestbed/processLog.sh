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
db=$logFile.db
tfDir=tmp
mkdir -p $tfDir

tickLen="4/26e6"
RXREADY_FAULT_WINDOW=3.0

#dos2unix $logFile

#depthTf=$(tempfile -d $tfDir)
tfb=$(tempfile -d $tfDir)
rxTf=$tfb.rx
txTf=$tfb.tx
irTf=$tfb.ir
rTf=$tfb.r
rsTf=$tfb.rs
pcTf=$tfb.pc
dcTf=$tfb.dc.csv
prrTf=$tfb.prr.csv
gapsTf=$tfb.gaps.csv
rxrTf=$tfb.rxr

#echo "extracting depth info"
#pv $logFile | awk '($3 == "s" || $3 == "S"){print $1,$2,$4}' > $depthTf
echo "extracting RX"
pv $logFile | awk '($3 == "RX" && (/s: 0/ || $2 == 0))&&(NF == 15){print $1,$5,$2,$7,$9, $11, 1}' > $rxTf
echo "extracting TX"
pv $logFile | awk '($3 == "TX"){print $1,$5,$7,$9, $11, $13}' > $txTf
echo "extracting duty cycle info"
pv $logFile | awk '($3 == "RS"){print $1, $2, $4, $5, $6, $7}' > $rsTf
echo "extracting forward/rx packet counts"
pv $logFile | awk '/^[0-9]+.[0-9]+ [0-9]+ PC [0-9]+ Sent [0-9]+ Received [0-9]+/{print $1, $2, $4, $6, $8}' > $pcTf
echo "Finding RXREADY faults"
pv $logFile | awk '/RXREADY/{print $1, $2}' > $rxrTf

sqlite3 $db << EOF
DROP TABLE IF EXISTS DEPTH;
CREATE TABLE DEPTH (
  ts REAL,
  node INTEGER,
  depth INTEGER
);
.separator ' '
--select "Importing Depth from $depthTf";
--.import $depthTf DEPTH

--select "Aggregating depth";
--DROP TABLE IF EXISTS AGG_DEPTH;
--CREATE TABLE AGG_DEPTH AS
--SELECT node,
--  min(depth) as minDepth, 
--  max(depth) as maxDepth,
--  avg(depth) as avgDepth,
--  count(*) as cnt
--FROM DEPTH
--GROUP BY node
--ORDER BY avgDepth;

DROP TABLE IF EXISTS TX_ALL;
CREATE TABLE TX_ALL (
  ts REAL,
  src INTEGER,
  dest INTEGER,
  sn INTEGER,
  rm INTEGER,
  pr INTEGER
);
select "Importing TX_ALL from $txTf";
.import $txTf TX_ALL

DROP TABLE IF EXISTS RXR;
CREATE TABLE RXR(
  ts REAL,
  node INTEGER
);

select "Importing RXREADY faults from $rxrTf";
.import $rxrTf RXR

--generate ranges affected by errors
DROP TABLE IF EXISTS RXR_RANGE;
CREATE TABLE RXR_RANGE
AS
SELECT 
  node,
  ts - (${RXREADY_FAULT_WINDOW}/2.0) as start,
  ts + (${RXREADY_FAULT_WINDOW}/2.0) as end
FROM RXR;

select "Removing impacted transmissions";

--identify the transmissions affected
DROP TABLE IF EXISTS RXR_FAULTS;
CREATE TABLE RXR_FAULTS AS
SELECT
  TX_ALL.src,
  TX_ALL.sn
FROM TX_ALL
JOIN RXR_RANGE ON
  TX_ALL.src == RXR_RANGE.node
  AND TX_ALL.ts > RXR_RANGE.start
  AND TX_ALL.ts < RXR_RANGE.end;

--invert this selection to get the valid transmissions
DROP TABLE IF EXISTS RXR_TX;
CREATE TABLE RXR_TX AS
SELECT 
  TX_ALL.src,
  TX_ALL.sn
FROM TX_ALL
EXCEPT
SELECT src, sn
FROM RXR_FAULTS;

--use join to intersect the valid transmission identifiers with the
--  full transmission records
DROP TABLE IF EXISTS TX;
CREATE TABLE TX AS
SELECT 
  TX_ALL.*
FROM TX_ALL
JOIN RXR_TX 
  ON RXR_TX.src == TX_ALL.src
  AND RXR_TX.sn == TX_ALL.sn;


DROP TABLE IF EXISTS RX_D;
CREATE TABLE RX_D (
  ts REAL,
  src INTEGER,
  dest INTEGER,
  pDest INTEGER,
  sn INTEGER,
  depth INTEGER,
  received INTEGER
);
select "Importing RX_D from $rxTf";
.import $rxTf RX_D

select "Aggregating depth info";
DROP TABLE IF EXISTS AGG_DEPTH;
CREATE TABLE AGG_DEPTH AS 
SELECT dest as node,
  min(depth) as minDepth,
  max(depth) as maxDepth,
  avg(depth) as avgDepth,
  count(*) as cnt
FROM RX_D
WHERE src == 0
GROUP BY dest
ORDER BY avgDepth;

DROP TABLE IF EXISTS RX;
CREATE TABLE RX AS
SELECT ts, src, dest, pDest, sn, received 
FROM RX_D;

DROP TABLE IF EXISTS RS_RAW;
CREATE TABLE RS_RAW (
  ts REAL,
  node INTEGER,
  rn INTEGER,
  state INTEGER,
  total_upper INTEGER,
  total_lower INTEGER
);
select "Importing RS_RAW from $rsTf";
.import $rsTf RS_RAW

DROP TABLE IF EXISTS PC;
CREATE TABLE PC (
  ts REAL,
  node INTEGER,
  rn INTEGER,
  txc INTEGER,
  rxc INTEGER
);
select "Importing PC from $pcTf";
.import $pcTf PC

select "Combining upper/lower RS totals";
DROP TABLE IF EXISTS RS;
CREATE TABLE RS AS
  SELECT ts,
    node,
    rn,
    state,
    (total_upper << 32) + total_lower as total
  FROM RS_RAW
  ORDER BY ts, node;

select "Processing duty cycle step 1";
DROP TABLE IF EXISTS RS_FRACTION;
CREATE TABLE RS_FRACTION AS
  SELECT RS_TOTAL.rnTs as ts, 
    RS_TOTAL.node as node, 
    RS_TOTAL.rn as rn, 
    RS.state, 
    ((1.0*RS.total)/RS_TOTAL.rnTotal) as frac,
    RS.total * (4.0/26e6) as total
  FROM ( 
    SELECT max(ts) as rnTS, node, rn, sum(total) as rnTotal
    FROM RS 
    GROUP BY node, rn
  ) RS_TOTAL 
  JOIN RS ON RS.node == RS_TOTAL.node AND RS.rn == RS_TOTAL.rn
  ORDER BY ts, node;

select "Processing duty cycle step 2";
DROP TABLE IF EXISTS RS_ACTIVE_CUMULATIVE;
CREATE TABLE RS_ACTIVE_CUMULATIVE AS
  SELECT inactive.ts as ts, inactive.node as node, inactive.rn as rn, 
    active.frac as activeFrac, 
    inactive.frac as inactiveFrac, 
    active.total as activeTotal, 
    inactive.total as inactiveTotal
  FROM 
  ( 
    SELECT max(ts) as ts, node, rn, sum(frac) as frac, sum(total) as total
    FROM RS_FRACTION
    WHERE state in (0,80)
    GROUP BY node, rn
  ) inactive JOIN 
  ( 
    SELECT node, rn, sum(frac) as frac, sum(total) as total
    FROM RS_FRACTION
    WHERE state not in (0,80)
    GROUP BY node, rn
  ) active 
  ON inactive.node == active.node AND inactive.rn == active.rn
  ORDER by inactive.ts, node;

select "Processing duty cycle step 3";
DROP TABLE IF EXISTS RS_ACTIVE;
CREATE TABLE RS_ACTIVE AS
  SELECT l.ts as t0, r.ts as t1, 
    l.node as node,
    (r.activeTotal   - l.activeTotal)/(
      (r.inactiveTotal + r.activeTotal)-
      (l.inactiveTotal + l.activeTotal)) as activeFrac
  FROM RS_ACTIVE_CUMULATIVE l
  JOIN RS_ACTIVE_CUMULATIVE r
  ON l.node == r.node and l.rn + 1 == r.rn
  ORDER BY l.ts, l.node;


select "Finding nr packet losses";
DROP TABLE IF EXISTS MISSING_NR_SN;
CREATE TABLE MISSING_NR_SN AS 
  SELECT tx.src as src, 
    tx.sn as sn, 
    allNodes.node as dest 
    FROM tx JOIN (
     -- SELECT 0 as node
      SELECT distinct src as node from tx 
      EXCEPT SELECT 0
      ) allNodes
    WHERE tx.src==0
    AND ( tx.dest=65535 OR tx.dest = allNodes.node)
  --  and allNodes.node == 1
    EXCEPT SELECT rx.src, rx.sn, rx.dest
    FROM rx;

DROP TABLE IF EXISTS MISSING_NR_RX;
CREATE TABLE MISSING_NR_RX AS
  SELECT tx.ts, 
    missing_nr_sn.src,
    missing_nr_sn.dest,
    tx.dest as pDest,
    missing_nr_sn.sn,
    0 as received
  FROM MISSING_NR_SN 
  JOIN TX 
  ON tx.src == missing_nr_sn.src 
    AND tx.sn == missing_nr_sn.sn;

select "Finding r packet losses";
DROP TABLE IF EXISTS MISSING_R_SN;
CREATE TABLE MISSING_R_SN AS 
  SELECT tx.src as src, 
    tx.sn as sn, 
    allNodes.node as dest 
    FROM tx JOIN (
      SELECT 0 as node
     -- SELECT distinct src as node from tx 
     -- EXCEPT SELECT 0
      ) allNodes
    WHERE tx.src!=0
    AND (tx.dest=65535 OR tx.dest == allNodes.node)
  --  and allNodes.node == 1
    EXCEPT SELECT rx.src, rx.sn, rx.dest
    FROM rx;

DROP TABLE IF EXISTS MISSING_R_RX;
CREATE TABLE MISSING_R_RX AS
  SELECT tx.ts, 
    missing_r_sn.src,
    missing_r_sn.dest,
    tx.dest as pDest,
    missing_r_sn.sn,
    0 as received
  FROM MISSING_R_SN 
  JOIN TX 
  ON tx.src == missing_r_sn.src 
    AND tx.sn == missing_r_sn.sn;

select "joining tx rx";
DROP TABLE IF EXISTS CONN;
 CREATE TABLE CONN AS 
   SELECT tx.ts as ts, 
     tx.src as src, 
     allRX.dest as dest, 
     tx.dest as pDest,
     tx.sn as sn,
     tx.rm as rm,
     tx.pr as pr,
     allRX.received as received
   FROM TX 
   LEFT JOIN (
     SELECT * FROM RX
     UNION
     SELECT * FROM MISSING_R_RX
     UNION 
     SELECT * FROM MISSING_NR_RX
  ) allRX ON
     allRX.src == tx.src AND
     allRX.sn == tx.sn
   ORDER BY tx.ts
;


DROP TABLE IF EXISTS RADIO_CURRENT;
CREATE TABLE RADIO_CURRENT (
  state INTEGER,
  currentA REAL);

.separator ' '
.import radio_current.ssv RADIO_CURRENT
  

select "consolidating to high level total duty cycle";

--this assumes that the last timestamped and last numbered report are
-- the same for each node.
DROP TABLE IF EXISTS RS_CURRENT_LAST;
CREATE TABLE RS_CURRENT_LAST AS
  SELECT rs_fraction.node, 
    rs_fraction.ts, 
    rs_fraction.rn, 
    rs_fraction.state, 
    rs_fraction.frac ,
    radio_current.currentA
  FROM rs_fraction
  JOIN (
    SELECT node, max(ts) as rnTs, max(rn) as rn
    FROM rs_fraction
    GROUP BY node
  ) lastRn 
  ON rs_fraction.node == lastRn.node 
    AND rs_fraction.rn == lastRn.rn
  JOIN radio_current ON radio_current.state == rs_fraction.state
  ;

DROP TABLE IF EXISTS LAST_CURRENT_AVG;
CREATE TABLE LAST_CURRENT_AVG AS
  SELECT node, max(ts), sum(frac*currentA) as avgCurrent
  FROM RS_CURRENT_LAST
  GROUP BY node;

DROP TABLE IF EXISTS LAST_ACTIVE;
CREATE TABLE LAST_ACTIVE AS 
  SELECT RS_ACTIVE_CUMULATIVE.node, ts, activeFrac
  FROM RS_ACTIVE_CUMULATIVE
  JOIN (
    SELECT node, max(rn) as rn
    FROM RS_ACTIVE_CUMULATIVE
    GROUP BY node
  ) LAST_AC
  ON LAST_AC.node == RS_ACTIVE_CUMULATIVE.node
    AND LAST_AC.rn == RS_ACTIVE_CUMULATIVE.rn;


DROP TABLE IF EXISTS FINAL_PRR;
CREATE TABLE FINAL_PRR AS 
  SELECT 
    src, 
    dest, 
    avg(received) as prr
  FROM conn 
  WHERE src ==0 or dest == 0
  GROUP BY src, dest
  ORDER BY src, dest;

--assume that 10 rounds are enough for the initial schedule
-- distribution
DROP TABLE IF EXISTS FINAL_PRR_NO_STARTUP;
CREATE TABLE FINAL_PRR_NO_STARTUP AS 
  SELECT 
    src, 
    dest, 
    avg(received) as prr
  FROM conn 
  WHERE (src ==0 or dest == 0) and sn > 10
  GROUP BY src, dest
  ORDER BY src, dest;

DROP TABLE IF EXISTS rx_tx_delta;

CREATE TABLE rx_tx_delta as
SELECT * 
--tCount.src, tCount.cnt - rCount.cnt
FROM 
  (
   SELECT 
   dest, 
   count(*) as rCount
   FROM RX
   WHERE src == 0
   GROUP BY dest
  ) rCount
  JOIN 
  (
   SELECT src, count(*) as tCount
   FROM TX 
   GROUP BY src
  ) tCount 
  on tCount.src == rCount.dest
;

DROP TABLE IF EXISTS rx_ordered;
CREATE TABLE rx_ordered as 
SELECT * from rx
WHERE src == 0
ORDER by dest, ts;

-- looking at this, we can see that basically all of the one-hop nodes
-- see a gap right at the start that corresponds to the synch timeout
-- period
DROP TABLE IF EXISTS rx_adj;
CREATE TABLE rx_adj as
SELECT l.dest as node, 
  l.ts as startGap,
  r.ts - l.ts as gapLen
FROM rx_ordered l
JOIN rx_ordered r
ON l.dest == r.dest AND l.rowid+1 == r.rowid
ORDER BY l.dest, l.ts;

--select * from AGG_DEPTH;
--select count(*) from AGG_DEPTH;
EOF

echo "dumping stats to file"
sqlite3 $db < duty_cycles.sql > $dcTf 
sqlite3 $db < prr_dist.sql > $prrTf 
sqlite3 $db < gaps.sql > $gapsTf 

#awk '($2==13){print $0}' debug/sf_13_burst_rxr | awk '/TX/{lastSn=$9} /RXREADY/{print lastSn}' > debug/sf_13_burst_rxr.rxready

echo "generating figures"
mkdir -p figs/$(dirname $logFile)
set -x
R --slave --no-save --args dataFile=$prrTf plotPdf=T \
  outPrefix=figs/$logFile label=$label < fig_scripts/prr.R
R --slave --no-save --args dataFile=$dcTf plotPdf=T \
  outPrefix=figs/$logFile label=$label < fig_scripts/dc.R
R --slave --no-save --args dataFile=$gapsTf \
  outPrefix=figs/$logFile label=$label < fig_scripts/gaps.R

if [ "$keepTemp" != "-k" ]
then
  rm $rxTf
  rm $txTf
  rm $irTf
  rm $rTf
  rm $rsTf
  rm $dcTf
  rm $prrTf
  rm $gapsTf
else
  echo "keeping temp files"
fi
#  | awk --assign n=$nodeId '($2==n){print $0}' | tr ' ' '\t'
