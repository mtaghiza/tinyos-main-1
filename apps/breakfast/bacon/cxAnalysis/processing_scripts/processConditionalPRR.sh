#!/bin/bash
if [ $# -lt 2 ]
then
  echo "Usage: $0 <log> <db> [rootId=0]" 1>&2
  exit 1
fi
log=$1
db=$2

rootId=0
if [ $# -gt 2 ]
then
  rootId=$3
fi

tf=tmpx
allData=$tf.all
sniffs=$tf.sniffs
transmits=$tf.transmits

echo "Adding unique ids"
pv $log | awk --assign rootId=$rootId '
  BEGIN{cycles=0}
  ($3 == "START" && $2 == rootId){cycles++}
  ($3 == "SD"){print $1, $2, $3, $6, $7, cycles}
  ($3 == "CXS" ){print $0, cycles }
' \
  > $allData

echo "extracting transmissions"
pv $allData | awk '($3 == "SD"){print $1, $2, $4, $5, $6}' > $transmits
echo "extracting receptions"
#np src sn count fn rssi lqi passed
pv $allData | awk '($3 == "CXS"){print $1, $2, $12, $5, $6, $9, $10, ($11 != 0), $7}' > $sniffs

sqlite3 $db <<EOF
select "Loading receptions";
DROP TABLE IF EXISTS sniffs;
CREATE TABLE SNIFFS (
  ts REAL,
  dest INTEGER,
  cycle INTEGER,
  src INTEGER,
  sn INTEGER,
  rssi INTEGER,
  lqi INTEGER,
  crcPassed INTEGER,
  hopCount INTEGER
);

.separator ' '
.import $sniffs SNIFFS

select "Loading transmissions";
DROP TABLE IF EXISTS transmits;
CREATE TABLE transmits (
  ts REAL,
  src INTEGER,
  sn INTEGER,
  hopCount INTEGER,
  cycle INTEGER
);
.import $transmits transmits

select "Computing conditional prrs (this may take a while)";
DROP TABLE IF EXISTS conditional_prr;
CREATE TABLE conditional_prr AS
SELECT
cond.dest as cd, ref.dest as rd, avg(cond.crcPassed) as condPrr
FROM sniffs cond
JOIN sniffs ref
ON cond.cycle = ref.cycle AND cond.sn=ref.sn AND cond.hopCount = ref.hopCount and abs(cond.ts - ref.ts) < 0.5
WHERE ref.crcPassed = 1  
AND ref.hopCount = 2
group by cond.dest, ref.dest
order by cond.dest, ref.dest;

select "counting senders per round";

DROP TABLE IF EXISTS numSenders;
CREATE TABLE numSenders as
SELECT cycle, sn, hopCount, count(*) as sendCount 
FROM transmits group by hopCount, cycle, sn;

select "grouping receptions by num senders";
DROP TABLE IF EXISTS group_results;
CREATE TABLE group_results as 
select sniffers.dest, n.cycle, n.sn, n.hopCount, n.sendCount,
  coalesce(crcPassed, 0) as rxOK, s.rssi as rssi
FROM numSenders n
JOIN (select distinct dest from sniffs) sniffers
left join sniffs s 
  on s.cycle=n.cycle 
  and s.sn = n.sn 
  and s.hopCount = n.hopCount
  and s.crcPassed = 1;

select "grouping receptions by sender";
DROP TABLE IF EXISTS single_results;
CREATE TABLE single_results as
SELECT t.*, g.dest, g.sendCount, g.rxOK
FROM transmits t
JOIN group_results g
  ON t.cycle=g.cycle
  AND t.sn = g.sn
  AND t.hopCount = g.hopCount;


select "computing prr w. / wo. node";
DROP TABLE if exists prr_v_node;
CREATE TABLE prr_v_node as 
SELECT src, hopCount, sendCount, involved, avg(rxOK) as prr, 
  count(*) as cnt
FROM (
SELECT nodes.src, g.sendCount, g.hopCount, coalesce(involved, 0) as involved,
  g.rxOK as rxOK
FROM group_results g
JOIN (select distinct src from single_results) nodes
LEFT JOIN (
  SELECT *, 1 as involved
  FROM single_results
  ) s
ON g.cycle = s.cycle AND g.sn = s.sn AND g.hopCount = s.hopCount and
nodes.src = s.src
) x
GROUP BY src, hopCount, sendCount, involved;

DROP TABLE IF EXISTS link;
CREATE TABLE link AS
SELECT 
s.src as src,
s.dest as dest,
avg(rssi) as avgRssi,
avg(lqi) as avgLqi
FROM sniffs
JOIN single_results s
ON s.cycle=sniffs.cycle and s.sn=sniffs.sn and s.hopCount=sniffs.hopCount
WHERE s.hopCount=2 and s.sendCount=1
GROUP BY s.src, s.dest;

EOF
