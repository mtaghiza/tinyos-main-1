#!/bin/bash

if [ $# -lt 2 ]
then
  exit 1
fi

f=$1
db=$2


mkdir -p tmp
cf=tmp/ch.txt
tf=tmp/ltx.txt
rf=tmp/lrx.txt
#1371673740.1 11 CH 11 0 0 1 4919
awk '/CH/{print $1, $2, $4, $5, $6, $7, $8}' $f > $cf

#1371732952.84 40 LTX 40 44 65535 1
awk '/LTX/{print $1, $2, $4, $5, $6, $7}' $f > $tf

#1371732952.84 35 LRX 40 44 65535 3 1
awk '/LRX/{print $1, $2, $4, $5, $6, $7, $8}' $f > $rf

touch $db
rm $db

sqlite3 $db <<EOF
.separator ' '
create table ch (
  ts REAL,
  node INTEGER,
  src INTEGER,
  sn INTEGER,
  i INTEGER,
  tx INTEGER,
  crc TEXT);

SELECT "Importing crcs";
.import $cf ch


SELECT "Importing LTX records";
create table ltx (
  ts REAL,
  node INTEGER,
  src INTEGER,
  sn INTEGER,
  dest INTEGER,
  retx INTEGER); 

.import $tf ltx

SELECT "Importing LRX records";
create table lrx (
  ts REAL,
  node INTEGER,
  src INTEGER,
  sn INTEGER,
  dest INTEGER,
  hc INTEGER,
  retx INTEGER); 
.import $rf lrx

SELECT "identifying non-probe transmissions";
CREATE table nonProbe as
SELECT src, sn FROM ltx WHERE retx=1;

SELECT "Identifying reference transmissions";
create table ref as 
SELECT ch.src, ch.sn, ch.i, ch.crc 
FROM ch 
JOIN nonProbe ON nonProbe.src = ch.src and nonProbe.sn = ch.sn 
WHERE ch.src = ch.node and ch.tx=1;

SELECT "Identifying CRC conflicts";

create TABLE 
failures AS 
SELECT * 
FROM
ch 
JOIN ref
ON ch.src = ref.src
AND ch.src != ch.node
AND ch.sn = ref.sn
AND ch.i = ref.i
AND ch.tx = 1
AND ch.crc != ref.crc;

SELECT count(*) as FailedCount from failures;

create TABLE tx AS
SELECT ltx.*
FROM ltx
JOIN nonProbe on ltx.src=nonProbe.src and ltx.sn=nonProbe.sn;


SELECT "matching tx to rx + missed";
DROP TABLE IF EXISTS rxm;
CREATE TABLE rxm
AS 
SELECT tx.ts, tx.src, tx.sn, tx.dest, nodes.node, coalesce(rx.received, 0) as received
FROM tx
JOIN (SELECT distinct node
FROM ch) nodes ON tx.src != nodes.node
LEFT JOIN (
  select lrx.*, 1 as received
  FROM lrx) as rx
ON rx.src=tx.src and rx.sn = tx.sn 
AND rx.node = nodes.node
;

SELECT "Computing pairwise PRRs";
CREATE TABLE prr as
SELECT src, 
  node as dest, 
  (1.0*sum(received))/count(*) as PRR,
  sum(received) as rxc
FROM rxm
GROUP BY src, node;

EOF
