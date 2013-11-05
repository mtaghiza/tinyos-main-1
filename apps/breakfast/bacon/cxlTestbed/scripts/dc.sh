#!/bin/bash

f=$1
db=$2

t=data/tmp
ss=${t}.ss

#TODO: something is causing nodes to occasionally double-log the last
# slot. this is particularly common at routers (where they are still
# logging the end of the router download when they start the leaf
# download)
# ts            n    wn sn total   off idle    sleep rx tx      fstxon  role
# 1382111831.77 0 SS 1  0  8145594 0   1797253 0     0  1547202 4801111 1
# 1             2    4  5  6       7   8       9     10 11      12      13
pv $f | tr '_' ' ' | awk '/ SETUP /{
  for(i=4; i < NF; i+=2){
    if ($i == "installTS"){ 
      it[$2]=$(i+1)
    }
  }
}
($3 == "SS"){
  if ($4 == 0){
    lastSS[$2]= $1 " " $2 " " $5 " " $6
  }else{
    lastSS[$2] = lastSS[$2] " " $5
  }
  if ($4 == 8){
    print it[$2], lastSS[$2]
  }
}' | awk '(NF == 13){print $0}' > $ss

sqlite3 $db <<EOF
.separator ' '
SELECT "Loading radio usage";
DROP TABLE IF EXISTS RADIO;
CREATE TABLE RADIO (
  it INTEGER,
  ts FLOAT,
  node INTEGER,
  wn INTEGER,
  slotNum INTEGER,
  total INTEGER,
  off INTEGER,
  idle INTEGER,
  sleep INTEGER,
  rx INTEGER,
  tx INTEGER,
  fstxon INTEGER,
  role INTEGER 
);

.import $ss RADIO

DROP TABLE IF EXISTS ROLE;
CREATE TABLE ROLE (
  role INTEGER,
  val text);

SELECT "consolidating radio usage: active v. idle";
DROP TABLE IF EXISTS ACTIVE_FLAT;
CREATE TABLE ACTIVE_FLAT AS 
SELECT it, ts, node, wn, slotNum, role,
  total,
  (total/6.5e6) as totalS,
  (rx + tx + fstxon) as active,
  (rx + tx + fstxon)/6.5e6 as activeS,
  (rx + tx + fstxon)/(1.0*total) as frac
FROM RADIO;

SELECT "consolidating radio usage: scale active";
DROP TABLE IF EXISTS ACTIVE;
CREATE TABLE ACTIVE AS 
SELECT it, ts, node, wn, slotNum, role,
  total,
  (total/6.5e6) as totalS,
  ((18.0*rx) + (18.0*tx) + (9.5*fstxon))/18.0 as active,
  (((18.0*rx) + (18.0*tx) + (9.5*fstxon))/18.0)/6.5e6 as activeS,
  (((18.0*rx) + (18.0*tx) + (9.5*fstxon))/18.0 )/total as frac,
  (rx+tx+fstxon)/(1.0*total) as fracEqual,
  (((18.0*rx) + (18.0*tx) + (0*fstxon))/18.0 )/total as fracFree
FROM RADIO;

INSERT INTO ROLE (role, val) VALUES (0, 'unknown');
INSERT INTO ROLE (role, val) VALUES (1, 'owner');
INSERT INTO ROLE (role, val) VALUES (2, 'forwarder');
INSERT INTO ROLE (role, val) VALUES (3, 'nonforwarder');
INSERT INTO ROLE (role, val) VALUES (4, 'wakeup');

select "totalling radio on-time by wakeup";
DROP TABLE IF EXISTS activeTot;
CREATE TABLE activeTot AS 
SELECT it, node, wn, 
  sum(activeS) as activeLen,
  sum(totalS) as totalLen, 
  sum(activeS)/sum(totalS) as dc 
FROM active
WHERE role!=5 group by it, node, wn;
EOF
