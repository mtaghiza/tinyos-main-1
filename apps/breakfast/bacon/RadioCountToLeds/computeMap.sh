#!/bin/bash
if [ $# -lt 1 ]
then
  echo "Usage: $0 [-r] <testbed log file>"
  echo "  if -r is specified, will try to grab logs/current from mojo"
  exit 1
fi
if [ "$1" == "-r" ]
then 
  shift 1
  tbFile=$1
  wget http://sensorbed.hinrg.cs.jhu.edu/logs/current -O $tbFile
else
  tbFile=$1
fi
dos2unix $tbFile
ssv=$tbFile.ssv
db=$tbFile.db
awk '/RX/{print $4, $5, $6, $7, $8}'  $tbFile > $ssv

sqlite3 $db <<EOF
DROP TABLE IF EXISTS RX;
CREATE TABLE RX (
  src INTEGER,
  dest INTEGER,
  rssi INTEGER,
  lqi INTEGER,
  sn INTEGER
);
.separator ' '
.import $ssv RX
DROP TABLE IF EXISTS AGG;
CREATE TABLE AGG AS SELECT src, dest, avg(rssi) as rssi, avg(lqi) as lqi,
(1.0*count(*))/(max(sn)-min(sn)+1.0) as prr, count(*) as cnt from RX group by src,
dest order by count(*);
EOF
