#!/bin/bash
#snifferId=1
if [ $# -lt 2 ]
then
  echo "Usage: $0 <log> <db> [rootId=5]" 1>&2
  exit 1
fi
log=$1
db=$2

rootId=5
if [ $# -gt 2 ]
then
  rootId=$3
fi

#tf=$(tempfile tmp)
tf=tmpx
allData=$tf.all
sniffs=$tf.sniffs
rawSniffs=$tf.rawSniffs
transmits=$tf.transmits
set -x
dos2unix $log
#when it gets rebroadcast, record which nodes sent it.
#ts, node, sn, cnt
cat $log | awk --assign rootId=$rootId '
  BEGIN{cycles=0}
  ($3 == "START" && $2 == rootId){cycles++}
  ($3 == "SD"){print $1, $2, $3, $6, $7, cycles}
  ($3 == "S" ) && /^[0-9]+\.[0-9]+ [0-9]+ S [0-9A-F]+ -[0-9]+ [0-9]+ [0-9]+$/{print $0, cycles }
' \
  > $allData

cat $allData | awk  \
  '($3 == "S" ) && /^[0-9]+\.[0-9]+ [0-9]+ S [0-9A-F]+ -[0-9]+ [0-9]+ [0-9]+ [0-9]+$/{print $0}' \
  > $rawSniffs

cat $allData | awk '($3 == "SD"){print $1, $2, $4, $5, $6}' > $transmits


cat $rawSniffs | python processing_scripts/ber.py -c 2 \
  > $sniffs

sqlite3 $db <<EOF
DROP TABLE IF EXISTS sniffs;
CREATE TABLE SNIFFS (
  cycle INTEGER,
  sn INTEGER,
  crcPassed INTEGER,
  hopCount INTEGER,
  errors INTEGER,
  total INTEGER
);

.separator ' '
.import $sniffs SNIFFS

DROP TABLE IF EXISTS transmits;
CREATE TABLE transmits (
  ts REAL,
  node INTEGER,
  sn INTEGER,
  hopCount INTEGER,
  cycle INTEGER
);
.import $transmits transmits

DROP TABLE IF EXISTS numSenders;
CREATE TABLE numSenders as
SELECT cycle, sn, hopCount, count(*) as sendCount 
FROM transmits group by hopCount, cycle, sn;

DROP TABLE IF EXISTS group_results;
CREATE TABLE group_results as 
select n.cycle, n.sn, n.hopCount, n.sendCount, coalesce(crcPassed, 0) as rxOK 
FROM numSenders n
left join sniffs s 
  on s.cycle=n.cycle 
  and s.sn = n.sn 
  and s.hopCount = n.hopCount;

DROP TABLE IF EXISTS single_results;
CREATE TABLE single_results as
SELECT t.*, g.sendCount, coalesce(s.crcPassed, 0) as rxOK
FROM transmits t
JOIN group_results g
  ON t.cycle=g.cycle
  AND t.sn = g.sn
  AND t.hopCount = g.hopCount
LEFT JOIN sniffs s
ON s.cycle = t.cycle 
  and s.sn = t.sn 
  and s.hopCount = t.hopCount;

DROP TABLE if exists prr_v_node;
CREATE TABLE prr_v_node as 
SELECT node, hopCount, sendCount, involved, avg(rxOK) as prr, 
  count(*) as cnt
FROM (
SELECT nodes.node, g.sendCount, g.hopCount, coalesce(involved, 0) as involved,
  g.rxOK as rxOK
FROM group_results g
JOIN (select distinct node from single_results) nodes
LEFT JOIN (
  SELECT *, 1 as involved
  FROM single_results
  ) s
ON g.cycle = s.cycle AND g.sn = s.sn AND g.hopCount = s.hopCount and nodes.node = s.node
) x
GROUP BY node, hopCount, sendCount, involved;

EOF

#rm $sniffs
#rm $rawSniffs
#rm $transmits
