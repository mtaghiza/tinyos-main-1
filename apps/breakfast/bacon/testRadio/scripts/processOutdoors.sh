#!/bin/bash
if [ $# -lt 1 ]
then 
  echo "Usage: $0 <prefix> dir..." 1>&2
  exit 1
fi
prefix=$1
rssiFile=$prefix.rssi
receptionFile=$prefix.reception
shift 1

[ -f $rssiFile ] && rm $rssiFile
[ -f $receptionFile ] && rm $receptionFile

#set -x
while [ $# -gt 0 ]
do
  dir=$1
  echo "processing $dir"
#  if [ $(grep -c 'GPS_FIX_AVAIL=1' $iaFile) -eq 0 ]
#  then
#    echo "no GPS fix for $dir" 1>&2
#    shift 1
#    break
#  fi
#
#  rxFile=$(tempfile)
   rxFile=$prefix.rx
#  lat=$(grep LATITUDE $iaFile | head -1 | tr '=' ' ' | cut -d ' ' -f 1 --complement)
#  latDec=$(echo "$lat" | python $(dirname $0)/dmsToDec.py)
#  lon=$(grep LONGITUDE $dir/*.ia | head -1 | tr '=' ' ' | cut -d ' ' -f 1 --complement)
#  lonDec=$(echo "$lat" | python $(dirname $0)/dmsToDec.py)

  latDec=$(grep LATITUDE $1/distance | cut -d '=' -f 2)
  lonDec=$(grep LONGITUDE $1/distance | cut -d '=' -f 2)
  distance=$(grep DISTANCE $1/distance | cut -d '=' -f 2)
  
  [ -f $rxFile ] && rm $rxFile
  for f in $dir/*.rx
  do
    #bacon: first few lines have startup info. Telos: first few lines
    # are flushing buffer
    tail --lines=+20 $f \
      | awk '/^[0-9]+\.[0-9]+ RX [0-9]+ (0|1) (-)?[0-9]+ [0-9]+ [0-3] [0-9]+ [0-9]+ [0-9]+ (-)?[0-9]+ (0|1) [0-9]+ [0-3] 1$/{print $0}' \
      | cut -d ' ' -f 2 --complement >> $rxFile
  done
  
  txPower=$(head -1 $rxFile | cut -d ' ' -f 10)
  txFe=$(head -1 $rxFile | cut -d ' ' -f 13)
  awk --assign lat=$latDec --assign lon=$lonDec \
    --assign distance=$distance \
    --assign power=$txPower --assign txFe=$txFe \
    '{print distance, lon, lat, $6, txFe, power, $4}' $rxFile >> $rssiFile

  awk --assign lat=$latDec --assign lon=$lonDec \
    --assign distance=$distance \
    --assign power=$txPower --assign txFe=$txFe \
    '{print distance, lon, lat, $6, txFe, power, $9}' $rxFile >> $receptionFile

  if [ $(ls $dir/*.ia 2>/dev/null | wc -l) -ne 1 ]
  then
    echo "more or fewer than one .ia file in $dir" 1>&2
  else
    iaFile=$1/*.ia
    dos2unix < $iaFile | \
      awk --assign lat=$latDec --assign lon=$lonDec \
      --assign distance=$distance \
      --assign power=$txPower --assign txFe=$txFe \
      -F '=' \
      '/^P_/{print distance, lon, lat, 2,  txFe, power, $2}' >> $rssiFile
  fi

  #read line
  shift 1
done

dbName=$prefix.db
[ -f $dbName ] && rm $dbName
sqlite3 $dbName <<EOF
CREATE TABLE RSSI (
  distance REAL,
  lon REAL,
  lat REAL,
  rxType INTEGER,
  txType INTEGER,
  power INTEGER,
  rssi REAL);
CREATE TABLE RECEPTION(
  distance REAL,
  lon REAL,
  lat REAL,
  rxType INTEGER,
  txType INTEGER,
  power INTEGER,
  sn REAL);
.separator ' '
.import $rssiFile RSSI
.import $receptionFile RECEPTION
CREATE TABLE PRR AS
  SELECT distance, lon, lat, rxType, txType, power, count(*)/(max(sn) - min(sn) + 1) as PRR
  FROM RECEPTION
  GROUP BY distance, lon, lat, rxType, txType, power;
EOF
sqlite3 $dbName <<EOF > $prefix.prr
.mode list
.separator ','
SELECT * from PRR ORDER BY distance, rxType, txType, power;
EOF

sqlite3 $dbName <<EOF > $prefix.rssi
.mode list
.separator ','
SELECT * from RSSI ORDER BY distance, rxType, txType, power;
EOF

sqlite3 $dbName <<EOF > $prefix.rssiSummary
.mode list
.separator ','
SELECT distance, lon, lat, rxType, txType, power, 
  max(rssi) as rssiMax, min(rssi) as rssiMin, 
  avg(rssi) as rssiAvg
FROM RSSI 
GROUP BY distance, lon, lat, rxType, txType, power
ORDER BY distance, lon, lat, rxType, txType, power;
EOF

sqlite3 $dbName <<EOF > $prefix.rssiStats
.mode list
.separator ','
DROP TABLE IF EXISTS rssiAvg;
CREATE TABLE rssiAvg as
SELECT distance, lon, lat, rxType, txType, power, avg(rssi) as rssiAvg
FROM rssi
GROUP BY distance, lon, lat, rxType, txType, power;

DROP TABLE IF EXISTS rssiSampleVar;
CREATE TABLE rssiSampleVar as
  SELECT rssi.distance as distance, rssi.lon as lon, rssi.lat as lat, 
    rssi.rxType as rxType, rssi.txType as txType, rssi.power as power,
    (rssi.rssi-rssiAvg.rssiAvg)*(rssi.rssi-rssiAvg.rssiAvg)/(count(*)-1)
    as var
  FROM rssi 
  JOIN rssiAvg 
    ON rssi.distance = rssiAvg.distance
    AND rssi.lon = rssiAvg.lon
    AND rssi.lat = rssiAvg.lat
    AND rssi.rxType = rssiAvg.rxType
    AND rssi.txType = rssiAvg.txType
    AND rssi.power = rssiAvg.power
  GROUP BY rssi.distance, rssi.lon, rssi.lat, rssi.rxType,
    rssi.txType, rssi.power;

drop table if exists rssiStats;
CREATE TABLE rssiStats as
  SELECT rssiAgg.distance, rssiAgg.lon, rssiAgg.lat, 
    rssiAgg.rxType, rssiAgg.txType, rssiAgg.power,
    rssiAgg.rssiMin, rssiAgg.rssiMax, rssiAgg.rssiAvg as
    rssiAvg, rssiSampleVar.var 
  FROM (
    SELECT distance, lon, lat, rxType, txType, power, 
      max(rssi) as rssiMax, min(rssi) as rssiMin, 
      avg(rssi) as rssiAvg
    FROM RSSI 
    GROUP BY distance, lon, lat, rxType, txType, power
  ) rssiAgg 
  JOIN rssiSampleVar ON (
    rssiSampleVar.distance = rssiAgg.distance
    AND rssiSampleVar.lat = rssiAgg.lat
    AND rssiSampleVar.lon = rssiAgg.lon
    AND rssiSampleVar.rxType = rssiAgg.rxType
    AND rssiSampleVar.txType = rssiAgg.txType
    AND rssiSampleVar.power = rssiAgg.power
  );
SELECT * from rssiStats 
ORDER BY
distance, rxType,txType,power;
EOF

rm $rxFile
rm $receptionFile
