#!/bin/bash

#1371673740.1 11 11 0 0 1 4919
awk '/CH/{print $1, $2, $4, $5, $6, $7, $8}' current > ch.txt

rm tmp.db
sqlite3 tmp.db <<EOF
.separator ' '
create table ch (
  ts REAL,
  node INTEGER,
  src INTEGER,
  sn INTEGER,
  i INTEGER,
  tx INTEGER,
  crc TEXT);
.import ch.txt ch


create table txCount as
SELECT src, sn, count(*) as cnt FROM ch where src=node and tx=1 group by src, sn;

drop table if exists ref;

create table ref as 
SELECT ch.src, ch.sn, ch.i, ch.crc 
FROM ch 
JOIN txCount ON txCount.src = ch.src and txCount.sn = ch.sn 
WHERE ch.src = ch.node and ch.tx=1 and txCount.cnt != 1;

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

EOF
