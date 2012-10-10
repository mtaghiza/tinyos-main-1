#!/bin/bash
#set -x
if [ $# -lt 1 ]
then
  echo "Usage: $0 <logFile> [1|0 (fec enabled)] [-k]" 1>&2
  echo " -k: keep (don't drop/recreate) tables" 1>&2
  exit 1
fi
logFile=$1
shift 1
recreate=1
fecEnabled=1
if [ $# -gt 0 ]
then
  fecEnabled=$1
  shift 1
fi 

if [ "$1" == "-k" ]
then 
  recreate=0
fi

tfDir=tmp
mkdir -p $tfDir
txFile=$(tempfile -d $tfDir)
rxFile=$(tempfile -d $tfDir)
#rxFile=tmp.rx

set -x 
if [ "$(file -b $logFile)" !=  "ASCII text" ]
then
  dos2unix $logFile
else
  echo "skipping dos2unix"
fi

#adjust TX len to reflect enabled checksum, if FEC enabled. note that lengths are in decoded bytes, not encoded bytes.
if [ $fecEnabled -eq 1 ]
then
  echo "Extracting TX: add internal CRC len"
  #ts sr power length sender sn
  pv $logFile | awk --re-interval \
    '/^[0-9]*\.[0-9]* [0-9]* TX( [0-9]*){6}$/{print $1,$4,$5,($6 + 2),$7,$9}' \
    > $txFile
else
  echo "Extracting TX: no internal CRC"
  #ts sr power length sender sn
  pv $logFile | awk --re-interval \
    '/^[0-9]*\.[0-9]* [0-9]* TX( [0-9]*){6}$/{print $1,$4,$5,$6,$7,$9}' \
    > $txFile
fi


echo "Extracting RX"
#ts sr power length sender sn receiver rssi lqi crc
pv $logFile | awk --re-interval \
  '/^[0-9]*\.[0-9]* [0-9]* RX( [0-9]*){7} -[0-9]*( [0-9]*){2}[ ]*$/{print $1,$4,$5,$6,$7,$10,$9,$11,$12,$13}' \
  > $rxFile

if [ $recreate -eq 1 ]
then
  echo "Creating tables"
  sqlite3 $logFile.db << EOF
    DROP TABLE IF EXISTS TX;
    CREATE TABLE TX (
      ts REAL,
      sr INTEGER,
      txPower INTEGER,
      len INTEGER,
      src INTEGER,
      sn INTEGER
    );
    
    DROP TABLE IF EXISTS RX;
    CREATE TABLE RX (
      ts REAL,
      sr INTEGER,
      txPower INTEGER,
      len INTEGER,
      src INTEGER,
      sn INTEGER,
      dest INTEGER,
      rssi INTEGER,
      lqi INTEGER,
      crc INTEGER
    );
    DROP TABLE IF EXISTS DEPTH;
    CREATE TABLE DEPTH ( 
      src INTEGER,
      dest INTEGER,
      avgDepth INTEGER,
      prrThreshold REAL,
      txPower INTEGER
    );
EOF

fi

sqlite3 $logFile.db  << EOF
.separator ' '
select "Loading TX";
.import $txFile TX
select "Loading RX";
.import $rxFile RX

SELECT "Creating TX Summary table";
DROP TABLE IF EXISTS TX_SUMMARY;
CREATE TABLE TX_SUMMARY AS 
SELECT sr, txPower, len, src, count(*) as sent,
  max(sn) as maxSN
FROM TX
GROUP BY sr, txPower, len, src;

SELECT "Creating RX Summary table";
DROP TABLE IF EXISTS RX_SUMMARY;
CREATE TABLE RX_SUMMARY AS
SELECT RX.sr as sr, 
  RX.txPower as txPower, 
  RX.len as len, 
  RX.src as src, 
  RX.dest as dest, 
  count(*) as received,
  avg(rssi) as avgRssi, 
  avg(lqi) as avgLqi
FROM RX
JOIN TX_SUMMARY ON 
  RX.sr == TX_SUMMARY.sr AND
  RX.txPower == TX_SUMMARY.txPower AND
  RX.len == TX_SUMMARY.len AND
  RX.src == TX_SUMMARY.src AND
  RX.sn <= TX_SUMMARY.maxSN
WHERE crc == 80
GROUP BY RX.sr, RX.txPower, RX.len, RX.src, RX.dest;

SELECT "Creating LINK table";
DROP TABLE IF EXISTS LINK;
CREATE TABLE LINK AS
SELECT 
  RX_SUMMARY.sr as sr,
  RX_SUMMARY.txPower as txPower,
  RX_SUMMARY.len as len,
  RX_SUMMARY.src as src,
  RX_SUMMARY.dest as dest,
  (1.0*RX_SUMMARY.received)/TX_SUMMARY.sent as prr,
  avgRssi,
  avgLqi
FROM TX_SUMMARY 
LEFT JOIN RX_SUMMARY ON 
  TX_SUMMARY.src == RX_SUMMARY.src AND 
  TX_SUMMARY.sr == RX_SUMMARY.sr AND
  TX_SUMMARY.txPower == RX_SUMMARY.txPower AND
  TX_SUMMARY.len == RX_SUMMARY.len
;

SELECT "Creating B_LINK table";
DROP TABLE IF EXISTS B_LINK;
CREATE TABLE B_LINK AS
SELECT a.txPower as txPower,
  a.sr as sr,
  a.len as len,
  a.src n0,
  b.src n1,
  b.prr p_01,
  a.prr p_10
FROM LINK a 
JOIN LINK b
ON a.src==b.dest AND b.src == a.dest 
AND a.txPower = b.txPower
AND a.sr = b.sr
AND a.len = b.len
;

SELECT "Generating fine-grained raw data (this may take a while)";
DROP TABLE IF EXISTS TXO;
CREATE TABLE TXO AS
SELECT
  TX.ts, TX.src, TX.sr, TX.len, TX.txpower, TX.sn, 
  allNodes.node as dest, 
  coalesce(RX.rssi, -1) as rssi,
  coalesce(RX.lqi, -1) as lqi,
  coalesce(RX.crc, 0) != 0 as received
FROM TX
JOIN (SELECT distinct src as node from tx) as allNodes
  ON allNodes.node != tx.src
LEFT JOIN RX ON
  TX.src = RX.src 
  AND allNodes.node == RX.dest
  AND TX.sn = RX.sn 
  AND RX.ts between (TX.ts - 10) and (TX.ts + 10)
;
EOF
#rm $txFile $rxFile
