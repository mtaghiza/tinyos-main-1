#!/bin/bash

f=$1
db=$2

t=data/tmp
tx=${t}.tx
rx=${t}.rx
wu=${t}.wu
s=${t}.s
e=${t}.e
setup=${t}.setup


dos2unix $f

echo "removing stray carriage returns"
pv $f | tr '\015' '\012' > $t
mv $t $f

echo "Extracting setups"
pv $f | grep 'SETUP' | sed 's/DL_/DL-/g' | tr '_' ' ' | awk '{
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
#ts            src w s sn pl dest
#1379977037.16 0 T 1 0 0 255 dest macType 
#1             2   4 5 6 7   8    9 
pv $f | tr '_' ' ' | awk '/ SETUP /{
  for(i=4; i < NF; i+=2){
    if ($i == "installTS"){ 
      it[$2]=$(i+1)
    }
  }
}
/WU/{
  channel[$2] = $5
  wut[$2] = $1
}
($3 == "T"){print it[$2], $1, $2, $4, $5, $6, $7, $8, $9, channel[$2], wut[$2]}' > $tx

echo "Extracting wakeup events"
pv $f | tr '_' ' ' | awk '/ SETUP /{
  for(i=4; i < NF; i+=2){
    if ($i == "installTS"){ 
      it[$2]=$(i+1)
    }
  }
}
/WU/{
  print it[$2], $1, $2, $5
}' > $wu


echo "Extracting RX events"
#ts            r   w s src sn  hc
#1379977037.17 2 R 1 0 0   139 1
#1             2   4 5 6   7   8
pv $f | tr '_' ' ' | awk '/ SETUP /{
  for(i=4; i < NF; i+=2){
    if ($i == "installTS"){ 
      it[$2]=$(i+1)
    }
  }
}
/WU/{
  channel[$2] = $5
}
($3 == "R"){print it[$2], $1, $2, $4, $5, $6, $7, $8, 1}' > $rx


echo "Extracting STATUS details"
#1  2     4 5    6  7
#ts src S w slot sn dp
pv $f | tr '_' ' ' | awk '/ SETUP /{
  for(i=4; i < NF; i+=2){
    if ($i == "installTS"){ 
      it[$2]=$(i+1)
    }
  }
}
($3 == "S"){print it[$2], $1, $2, $4, $5, $6, $7}' > $s

echo "Extracting EOS details"
pv $f | tr '_' ' ' | awk '/ SETUP /{
  for(i=4; i < NF; i+=2){
    if ($i == "installTS"){ 
      it[$2]=$(i+1)
    }
  }
}
($3 == "E"){print it[$2], $1, $2, $4, $5, $6, $7}' > $e

sqlite3 $db <<EOF
.separator ' '

SELECT "Loading raw RX";

DROP TABLE IF EXISTS RX;
CREATE TABLE RX (
  it INTEGER,
  ts FLOAT,
  node INTEGER,
  wn INTEGER,
  slotNum INTEGER,
  src INTEGER,
  sn INTEGER,
  hc INTEGER,
  received INTEGER);

.import $rx RX

SELECT "Loading raw TX";
DROP TABLE IF EXISTS TX;
CREATE TABLE TX (
  it INTEGER,
  ts FLOAT,
  src INTEGER,
  wn INTEGER,
  slotNum INTEGER,
  sn INTEGER,
  pl INTEGER,
  dest INTEGER,
  mt INTEGER,
  channel INTEGER,
  wut FLOAT);

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

SELECT "Loading wakeups";
DROP TABLE IF EXISTS wakeup;
CREATE TABLE wakeup (
  it INTEGER,
  ts FLOAT,
  node INTEGER,
  channel INTEGER
);

.import $wu wakeup

SELECT "Removing duplicate setup entries";
CREATE TEMPORARY TABLE lastSetup AS 
SELECT node, it, 
  max(ts) as ts
FROM setup 
GROUP BY node, it;

DELETE FROM setup 
WHERE rowid in (
  SELECT setup.rowid 
  FROM setup 
  JOIN lastSetup ON setup.node=lastSetup.node 
    AND setup.it = lastSetup.it 
    AND setup.ts != lastSetup.ts);

SELECT "Enumerating nodes";
DROP TABLE IF EXISTS nodes;
CREATE TABLE nodes AS SELECT distinct it, node FROM setup order by it, node;

SELECT "Finding missing RX (may take a while)";
DROP TABLE IF EXISTS RXR;
CREATE TABLE RXR AS 
SELECT TX.it as it, 
  TX.src as src, 
  TX.sn as sn, 
  wakeup.node as dest, 
  coalesce(received, 0) as received
FROM TX
JOIN wakeup
  ON wakeup.it = TX.it 
  AND wakeup.channel = tx.channel
  AND wakeup.ts > tx.wut - 10 and wakeup.ts < tx.wut + 10
  AND (TX.mt in (3, 5, 6) OR TX.dest = 65535 OR TX.dest=wakeup.node)
LEFT JOIN RX
  ON RX.it = TX.it 
    AND RX.src = TX.src 
    AND RX.sn = TX.sn 
    AND RX.node = wakeup.node
WHERE TX.src != wakeup.node;

SELECT "Computing PRR (may take a while)";

DROP TABLE IF EXISTS PRR;
CREATE TABLE PRR AS
SELECT it, src, dest, count(*) as txc, sum(received) as rxc,
  (sum(received)*1.0)/count(*) as prr
FROM RXR
GROUP BY it, src, dest;

-- DROP TABLE IF EXISTS PRR;
-- CREATE TABLE PRR AS
-- SELECT a.it, a.src, b.dest, a.cnt as txc, b.cnt as rxc,
--   b.cnt/(1.0*a.cnt) as prr
-- FROM (
--   SELECT it, src, count(*) as cnt FROM TX GROUP BY it, src
-- ) a
-- JOIN (
--   SELECT it, src, dest, sum(received) as cnt 
--   FROM RXR 
--   GROUP BY it, src, dest
-- ) b ON a.it = b.it AND a.src=b.src;

DROP TABLE IF EXISTS agg;
CREATE TABLE agg AS 
SELECT prr.it as it, txp.val as power, mct.val as mct, pa.val as pa, rxSlack.val as rxSlack, avg(prr) as prr
FROM prr 
JOIN setup as txp 
  ON txp.node=0 and txp.it=prr.it AND txp.key='lp'
JOIN setup as mct 
  ON mct.node=0 and mct.it=prr.it AND mct.key='mct'
JOIN setup as pa 
  ON pa.node=0 and pa.it=prr.it AND pa.key='pa'
JOIN setup as rxSlack
  on rxSlack.node=0 and rxSlack.it=prr.it and rxSlack.key='rxSlack'
JOIN setup as installed
  ON installed.node = prr.dest
  AND installed.key='installTS'
  AND installed.val=prr.it
WHERE src=0 
AND prr.dest not in (0)
AND prr.prr > 0.0
GROUP BY prr.it, txp.val, mct.val, pa.val, rxSlack.val
ORDER BY avg(prr);
EOF
