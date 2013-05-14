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
# ts            node          sched# sn csRemote csLocal
# 1             2             3      4  5        6
pv $logTf | grep 'SCHED' | cut -d ' ' -f 3,4 --complement > $schedTf

echo "extracting RX_LOCAL events"
# 1368558911.19 43   NRX 0   0  894      2  916881 923320    65535 -79  1
# tsReport      node     src sn ofnLocal hc rx32k  report32k dest  rssi lqi
# 1             2        3   4  5        6  7      8         9     10   11
pv $logTf | grep 'NRX' | cut -d ' ' -f 3 --complement > $rxlTf

echo "extracting TX_LOCAL events"
# 1368558936.21 0   NTX 1  803      822299 829762    65535 2  0   196
# tsReport      src     sn ofnLocal tx32k  report32k dest  tp stp AMID
# 1             2       3  4        5      6         7     8  9   10
pv $logTf | grep 'NTX' | cut -d ' ' -f 3 --complement > $txlTf

echo "extracting CRCF_LOCAL events"
# 1368558910.98 4    CRCF 981
# ts            node      fnLocal
pv $logTf | grep 'CRCF' | cut -d ' ' -f 3 --complement > $cflTf

echo "extracting FW_LOCAL events"
# 1368558936.01 25   NFW 12       2
# ts            node     ofnLocal hc
pv $logTf | grep 'NFW' | cut -d ' ' -f 3 --complement > $fwlTf


sqlite3 $db << EOF
.headers OFF
.separator ' '

DROP TABLE IF EXISTS SCHED_TMP;
CREATE TEMPORARY TABLE SCHED_TMP (
  ts REAL,
  node INTEGER,
  schedNum INTEGER,
  sn INTEGER,
  csRemote INTEGER,
  csLocal INTEGER);

.import $schedTf SCHED_TMP

DROP TABLE IF EXISTS SCHED;
CREATE TABLE SCHED AS 
  SELECT * FROM SCHED_TMP ORDER BY node, ts;

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

.import $rxlTf RX_LOCAL

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

.import $txlTf TX_LOCAL

DROP TABLE IF EXISTS CRCF_LOCAL;
CREATE TABLE CRCF_LOCAL (
  ts REAL,
  node INTEGER,
  fnLocal INTEGER);

.import $cflTf CRCF_LOCAL

DROP TABLE IF EXISTS FW_LOCAL;
CREATE TABLE FW_LOCAL (
  ts REAL,
  node INTEGER,
  ofnLocal INTEGER,
  hc INTEGER);

.import $fwlTf  FW_LOCAL

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
fi
