#!/bin/bash
#snifferId=1
rootId=0
if [ $# -lt 3 ]
then
  echo "Usage: $0 <log> <db> <fecEnabled> [rootId=$rootId]" 1>&2
  exit 1
fi
log=$1
db=$2
fecEnabled=$3
sd=$(dirname $0)

if [ $# -gt 3 ]
then
  rootId=$4
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

if [ $(grep -c '!' < $log) -gt 0 ]
then
  echo "$log contained errors, skipping"
  exit 0
fi

cat $log | awk  \
  '($3 == "S" ) && /^[0-9]+\.[0-9]+ [0-9]+ S [0-9A-F]+ -[0-9]+ [0-9]+ [0-9]+$/{print $0}'  \
  > $rawSniffs
if [ "$fecEnabled" == "1" ]
then
  python $sd/fecBer.py -f $rawSniffs -l 1 -o 1 -r 1 > $processed
else
  cat $rawSniffs | python $sd/ber.py \
    > $processed
fi

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
  outerCrcPassed INTEGER,
  hopCount INTEGER,
  bitErrors INTEGER,
  bitTotal INTEGER,
  byteErrors INTEGER
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
  contents TEXT,
  rssi INTEGER,
  lqi INTEGER);
.import $raw RAW

--remove first and last minute of data (inconsistent logging/startup)
DELETE FROM ber WHERE ts < $firstOrig + 60;
DELETE FROM ber WHERE ts > $lastOrig + 60;
DELETE FROM orig WHERE ts < $firstOrig + 60;
DELETE FROM orig WHERE ts > $lastOrig + 60;
DELETE FROM loc WHERE ts < $firstOrig + 60;
DELETE FROM loc WHERE ts > $lastOrig + 60;
EOF

if [ "$fecEnabled" == "1" ]
then
  sqlite3 $db <<EOF
select "Creating summary table";
DROP TABLE IF EXISTS ber_summary;
CREATE TABLE ber_summary as
SELECT rx/orig as prrAny,
  crc/orig as prrPass,
  fecPassed/orig as prrFec,
  errTot/bitTot as berEst,
  0 as prrAnyExpected,
  0 as prrPassExpected,
  orig as tx,
  rx as rx,
  crc as crcPassed,
  fecPassed as fecPassed
FROM(
  SELECT  1.0*origCount.cnt as orig, 
    1.0*rxCount.cnt as rx, 
    1.0*crcPassed.cnt as crc, 
    1.0*fecPassed.cnt as fecPassed,
    1.0*berAgg.errorBits as errTot, 
    1.0*berAgg.totalBits as bitTot
  FROM (SELECT count(*) as cnt from ber) rxCount
  JOIN (SELECT count(*) as cnt from ber where outerCrcPassed = 1) crcPassed
  JOIN (SELECT sum(bitErrors) errorBits, sum(bitTotal) totalBits FROM ber) berAgg
  JOIN (SELECT count(*) as cnt from orig) origCount
  JOIN (SELECT count(*) as cnt from ber where byteErrors == 0) fecPassed
);
EOF

else

  sqlite3 $db <<EOF
--Note that for non-FEC'ed data, we count crc-passed as fec-passed
DROP TABLE IF EXISTS ber_summary;
CREATE TABLE ber_summary as
SELECT rx/orig as prrAny,
  crc/orig as prrPass,
  fecPassed/orig as prrFec,
  errTot/bitTot as berEst,
  0 as prrAnyExpected,
  0 as prrPassExpected,
  orig as tx,
  rx as rx,
  crc as crcPassed,
  fecPassed as fecPassed
FROM(
  SELECT  1.0*origCount.cnt as orig, 
    1.0*rxCount.cnt as rx, 
    1.0*crcPassed.cnt as crc, 
    1.0*crcPassed.cnt as fecPassed,
    1.0*berAgg.errorBits as errTot, 
    1.0*berAgg.totalBits as bitTot
  FROM (SELECT count(*) as cnt from ber) rxCount
  JOIN (SELECT count(*) as cnt from ber where outerCrcPassed = 1) crcPassed
  JOIN (SELECT sum(bitErrors) errorBits, sum(bitTotal) totalBits FROM ber) berAgg
  JOIN (SELECT count(*) as cnt from orig) origCount
  JOIN (SELECT count(*) as cnt from ber where byteErrors == 0) fecPassed
);
EOF
fi

sqlite3 $db <<EOF
-- include sanity-check estimates of prr based on observed BER
UPDATE ber_summary SET prrAnyExpected = (SELECT max(0, 1.0-(berEst*(32 + 32))) as prrAnyExpected);
UPDATE ber_summary SET prrPassExpected = (SELECT max(0, 1.0-(berEst*(8 + 456 + 16))) as prrPassExpected);

-- -1: unknown number of bit errors (lost without a trace): 
--     this gives us some upper/lower bound 
DROP TABLE IF EXISTS error_counts;
CREATE TABLE error_counts AS
SELECT bitErrors, count(*) as cnt FROM ber GROUP BY bitErrors
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
