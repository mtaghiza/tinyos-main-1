#!/bin/bash
#snifferId=1
rootId=0
if [ $# -lt 2 ]
then
  echo "Usage: $0 <log> <db> [rootId=$rootId]" 1>&2
  exit 1
fi
log=$1
db=$2

if [ $# -gt 2 ]
then
  rootId=$3
fi

#tf=$(tempfile tmp)
tf=tmpx
rawSniffs=$tf.rawSniffs
processed=$tf.processed
ber=$tf.ber
loc=$tf.loc
orig=$tf.orig
raw=$tf.raw

set -x
dos2unix $log

cat $log | awk  \
  '($3 == "S" ) && /^[0-9]+\.[0-9]+ [0-9]+ S [0-9A-F]+ -[0-9]+ [0-9]+ [0-9]+$/{print $0}'  \
  > $rawSniffs

cat $rawSniffs | python processing_scripts/ber.py \
  > $processed

grep 'BER' $processed | cut -d ' ' -f 1 --complement > $ber
grep 'ORIG' $processed | cut -d ' ' -f 1 --complement > $orig
grep 'LOC' $processed | cut -d ' ' -f 1 --complement > $loc
grep 'RAW' $processed | cut -d ' ' -f 1 --complement > $raw

firstOrig=$(head -1 $orig | cut -d ' ' -f 1)
lastOrig=$(tail -1 $orig | cut -d ' ' -f 1)
sqlite3 $db <<EOF
.separator ' '

DROP TABLE IF EXISTS BER;
CREATE TABLE BER (
  ts REAL,
  sn INTEGER,
  crcPassed INTEGER,
  hopCount INTEGER,
  errors INTEGER,
  total INTEGER
);
.import $ber BER 

DROP TABLE IF EXISTS ORIG;
CREATE TABLE ORIG (
  ts REAL,
  sn INTEGER
);
.import $orig ORIG

DROP TABLE IF EXISTS LOC;
CREATE TABLE LOC (
  ts REAL,
  l INTEGER
);
.import $loc LOC

DROP TABLE IF EXISTS RAW;
CREATE TABLE RAW (
  ts REAL,
  sn INTEGER,
  cnt INTEGER,
  contents TEXT);
.import $raw RAW

--remove first and last minute of data (inconsistent logging/startup)
DELETE FROM ber WHERE ts < $firstOrig + 60;
DELETE FROM ber WHERE ts > $lastOrig + 60;
DELETE FROM orig WHERE ts < $firstOrig + 60;
DELETE FROM orig WHERE ts > $lastOrig + 60;
DELETE FROM loc WHERE ts < $firstOrig + 60;
DELETE FROM loc WHERE ts > $lastOrig + 60;

DROP TABLE IF EXISTS ber_summary;
CREATE TABLE ber_summary as
SELECT rx/orig as prrAny,
  crc/orig as prrPass,
  errTot/bitTot as berEst,
  0 as prrAnyExpected,
  0 as prrPassExpected
FROM(
  SELECT  1.0*origCount.cnt as orig, 
    1.0*rxCount.cnt as rx, 
    1.0*crcPassed.cnt as crc, 
    1.0*berAgg.errorBits as errTot, 
    1.0*berAgg.totalBits as bitTot
  FROM (SELECT count(*) as cnt from ber) rxCount
  JOIN (SELECT count(*) as cnt from ber where crcPassed = 1) crcPassed
  JOIN (SELECT sum(errors) errorBits, sum(total) totalBits FROM ber) berAgg
  JOIN (SELECT count(*) as cnt from orig) origCount
);

-- include sanity-check estimates of prr based on observed BER
UPDATE ber_summary SET prrAnyExpected = (SELECT max(0, 1.0-(berEst*(32 + 32))) as prrAnyExpected);
UPDATE ber_summary SET prrPassExpected = (SELECT max(0, 1.0-(berEst*(8 + 456 + 16))) as prrPassExpected);

-- -1: unknown number of bit errors (lost without a trace): 
--     this gives us some upper/lower bound 
DROP TABLE IF EXISTS error_counts;
CREATE TABLE error_counts AS
SELECT errors, count(*) as cnt FROM ber GROUP BY errors
UNION
SELECT -1, count(*) as cnt FROM orig WHERE sn NOT IN (SELECT sn FROM
ber);
EOF
exit 0

rm $rawSniffs
rm $processed
rm $ber
rm $loc
rm $orig
rm $raw
