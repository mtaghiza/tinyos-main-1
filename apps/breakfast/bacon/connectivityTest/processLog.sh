#!/bin/bash
set -x
if [ $# -lt 1 ]
then
  echo "Usage: $0 <logFile> [-r]" 1>&2
  echo " -c: drop/recreate tables" 1>&2
  exit 1
fi
logFile=$1
shift 1
recreate=0
if [ "$1" == "-r" ]
then 
  recreate=1
fi
tfDir=tmp
mkdir -p $tfDir
txFile=$(tempfile -d $tfDir)
rxFile=$(tempfile -d $tfDir)

if [ "$(file -b $logFile)" !=  "ASCII text" ]
then
  dos2unix $logFile
else
  echo "skipping dos2unix"
fi
#ts sr power length sender sn
pv $logFile | awk --re-interval \
  '/^[0-9]*\.[0-9]* [0-9]* TX( [0-9]*){6}$/{print $1,$4,$5,$6,$7,$9}' \
  > $txFile

#ts sr power length sender sn receiver rssi lqi crc
pv $logFile | awk --re-interval \
  '/^[0-9]*\.[0-9]* [0-9]* RX( [0-9]*){6} -[0-9]*( [0-9]*){2}$/{print $1,$4,$5,$6,$7,$9,$2,$10,$11,$12}' \
  > $rxFile

if [ $recreate -eq 1 ]
then
  echo "Recreating"
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
EOF

fi

sqlite3 $logFile.db  << EOF
.separator ' '
select "Loading TX";
.import $txFile TX
select "Loading RX";
.import $rxFile RX

DROP TABLE IF EXISTS TX_SUMMARY;
CREATE TABLE TX_SUMMARY AS 
SELECT sr, txPower, len, src, count(*) as sent,
  max(sn) as maxSN
FROM TX
GROUP BY sr, txPower, len, src;

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

DROP TABLE IF EXISTS B_LINK;
CREATE TABLE B_LINK AS
SELECT a.src n0,
  b.src n1,
  b.prr p_01,
  a.prr p_10
FROM LINK a 
JOIN LINK b
ON a.src==b.dest AND b.src == a.dest 
;
EOF
#rm $txFile $rxFile
