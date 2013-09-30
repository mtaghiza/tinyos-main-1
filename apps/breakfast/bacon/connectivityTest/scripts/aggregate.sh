#!/bin/bash

f=$1
db=$2

t=data/tmp
tx=${t}.tx
rx=${t}.rx
setup=${t}.setup

echo "Extracting setups"
pv $f | grep 'CONNECTIVITY' | sed 's/DL_/DL-/g' | tr '_' ' ' | awk '{
  for(i=4; i < NF; i+=2){
    settings[$i]=$(i+1)
  }
  it=settings["installTS"]
  node=$2
  ts=$1
  for (key in settings){
    print node, ts, it, key, settings[key]
  }
}' > $setup


echo "Extracting TX events"
# ts            n    sr  txp pl src dest  sn
# 1380467133.54 1 TX 125 45  22 1   65535 1
# 1             2    4   5   6      8     9
pv $f | tr '_' ' ' | awk '/ CONNECTIVITY /{
  for(i=4; i < NF; i+=2){
    if ($i == "installTS"){ 
      it[$2]=$(i+1)
    }
  }
}
($3 == "TX"){print it[$2], $1, $2, $4, $5, $6, $8, $9}' > $tx

echo "Extracting RX events"
# ts            n    sr  txp pl src dest  self sn rssi lqi crc
# 1380467133.55 0 RX 125 45  22 1   65535 0    1  -33  0   80
# 1             2    4   5   6  7              10 11   12  13
pv $f | tr '_' ' ' | awk '/ CONNECTIVITY /{
  for(i=4; i < NF; i+=2){
    if ($i == "installTS"){ 
      it[$2]=$(i+1)
    }
  }
}
($3 == "RX"){print it[$2], $1, $2, $7, $10, $11, $12, $13, 1}' > $rx

sqlite3 $db <<EOF
.separator ' '

SELECT "Loading raw RX";
DROP TABLE IF EXISTS RX;
CREATE TABLE RX (
  it INTEGER,
  ts FLOAT,
  node INTEGER,
  src INTEGER,
  sn INTEGER,
  rssi INTEGER,
  lqi INTEGER,
  crc INTEGER,
  received INTEGER);

.import $rx RX

SELECT "Loading raw TX";
DROP TABLE IF EXISTS TX;
CREATE TABLE TX (
  it INTEGER,
  ts FLOAT,
  src INTEGER,
  sr INTEGER,
  txp INTEGER,
  pl INTEGER,
  dest INTEGER,
  sn INTEGER
);

.import $tx TX

SELECT "Loading setup info";

DROP TABLE IF EXISTS setup;
CREATE TABLE setup (
  node INTEGER,
  ts FLOAT,
  it INTEGER,
  key TEXT,
  val TEXT);

.import $setup setup

SELECT "Enumerating nodes";
DROP TABLE IF EXISTS nodes;
CREATE TABLE nodes AS SELECT distinct node FROM setup order by node;

SELECT "Finding missing RX (may take a while)";
DROP TABLE IF EXISTS RXR;
CREATE TABLE RXR AS 
SELECT TX.it as it, 
  TX.src as src, 
  TX.sn as sn, 
  nodes.node as dest, 
  coalesce(received, 0) as received
FROM TX
JOIN nodes
  ON TX.src != nodes.node
LEFT JOIN RX
  ON RX.it = TX.it 
  AND RX.src = TX.src
  AND RX.sn = TX.sn
  AND RX.node = nodes.node;

SELECT "Computing PRR (may take a while)";

DROP TABLE IF EXISTS PRR;
CREATE TABLE PRR AS
SELECT a.it, a.src, b.dest, a.cnt as txc, b.cnt as rxc,
  b.cnt/(1.0*a.cnt) as prr
FROM (
  SELECT it, src, count(*) as cnt FROM TX GROUP BY it, src
) a
JOIN (
  SELECT it, src, dest, sum(received) as cnt 
  FROM RXR 
  GROUP BY it, src, dest
) b ON a.it = b.it AND a.src=b.src;

SELECT "Aggregating links over multiple tests";
DROP TABLE IF EXISTS agg;
CREATE TABLE agg AS 
SELECT txp.val as power, 
  channel.val as channel, 
  pl.val as pl, 
  prr.src as src,
  prr.dest as dest,
  avg(prr) as prr
FROM prr 
JOIN setup as txp 
  ON txp.node=prr.src 
    and txp.it=prr.it 
    AND txp.key='lp'
JOIN setup as channel 
  ON channel.node=prr.src 
    and channel.it=prr.it 
    AND channel.key='channel'
JOIN setup as pl
  ON pl.node = prr.dest
    AND pl.it=prr.it
    AND pl.key='tpl'
GROUP BY power, channel, pl, src, dest
ORDER BY avg(prr);

EOF
