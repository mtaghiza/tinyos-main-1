#!/bin/bash
if [ $# -lt 2 ]
then
  exit 1
fi
f=$1
db=$2

tf=$(tempfile)
tfFlat=$tf.flat
tfLabel=$tf.label
tail --lines=+2 $f  | tr -d ' ' > $tf

awk -F ',' '{
  ts=$1
  for (k = 2; k <= NF; k++){
    printf("%d,%s,%d,%d\n", NR, ts, k - 2, $k);
  }
}'  $tf > $tfFlat

head --lines=1 $f | \
  awk -F ',' '(NR==1){
    for (k = 2; k <= NF; k++){
      printf("%d,%s\n", k-2, $k);
    }
  }'> $tfLabel


sqlite3 $db <<EOF
DROP TABLE IF EXISTS bitrec;

CREATE TABLE bitrec (
  rn INTEGER, 
  ts REAL,
  bit INTEGER,
  val INTEGER);

--load all LA data

.separator ','
.import $tfFlat bitrec

--find changes
DROP TABLE IF EXISTS delta;
CREATE TABLE delta AS
  SELECT r.rn, r.ts, r.bit, r.val
  FROM bitrec l
  JOIN bitrec r
    ON l.rn+1 = r.rn AND l.bit = r.bit AND l.val != r.val
ORDER BY r.rn, r.bit;

--load labels
DROP TABLE IF EXISTS label;
CREATE TABLE label (
  bit INTEGER,
  label TEXT);
.import $tfLabel label

--make it easier to find the bits we care about
DROP TABLE IF EXISTS trigger;
CREATE TABLE trigger as
  SELECT bit from label 
  WHERE label LIKE '%trigger%';

DROP TABLE IF EXISTS txf;
CREATE TABLE txf as
  SELECT bit from label 
  WHERE label LIKE '%TXF%';

DROP TABLE IF EXISTS txv;
CREATE TABLE txv as
  SELECT bit from label 
  WHERE label LIKE '%TXV%';

EOF

cp $tfFlat tmp.flat
rm $tf
rm $tfFlat

