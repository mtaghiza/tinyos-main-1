#!/bin/bash
if [ $# -lt 2 ]
then
  exit 1
fi
log=$1
db=$2

dos2unix $log

pv $log | grep ' TX ' | cut -d ' ' -f 1,2,5 > tmp.tx
pv $log | grep ' RX ' | cut -d ' ' -f 1,2,4,5,6,7,8 > tmp.rx

sqlite3 $db <<EOF
.separator ' '
DROP TABLE IF EXISTS TX;
CREATE TABLE TX (
  ts REAL,
  src INTEGER,
  sn INTEGER
);
SELECT "Loading TX";
.import tmp.tx TX

DROP TABLE IF EXISTS RX;
CREATE TABLE RX (
  ts REAL,
  dest INTEGER,
  src INTEGER,
  sn INTEGER,
  hc INTEGER,
  rssi INTEGER,
  lqi INTEGER);

SELECT "Loading RX";
.import tmp.rx RX

select "Finding missing rx";
DROP TABLE IF EXISTS RXR;
CREATE TABLE RXR AS
SELECT tx.src as src, 
  nodes.dest as dest,
  tx.sn as sn, 
  coalesce(received, 0) as received,
  coalesce(hc, 0) as hc,
  coalesce(rssi, 0) as rssi,
  coalesce(lqi, 0) as lqi
FROM tx
JOIN (select distinct dest from rx) as nodes
  ON tx.src != nodes.dest
LEFT JOIN (select *, 1 as received FROM rx) as rx
  ON tx.src=rx.src
  AND rx.dest=nodes.dest
  AND tx.sn=rx.sn
  AND rx.ts between tx.ts - 5 and tx.ts+5
;

--single-transmitter links
SELECT "Computing single-transmitter links";
DROP TABLE IF EXISTS stl;
CREATE TABLE stl AS
SELECT rxr.src as src, 
  rxr.dest as dest, 
  avg(received AND hc=1) as prr,
  coalesce(phy.rssi, 0) as rssi,
  coalesce(phy.lqi, 0) as lqi
FROM rxr
LEFT JOIN (
  SELECT src, dest, 
  avg(rssi) as rssi, 
  avg(lqi) as lqi 
  FROM rxr
  WHERE hc=1 
  GROUP BY src, dest) phy
ON phy.src=rxr.src AND phy.dest=rxr.dest
GROUP BY src, dest;

--shortest path len: prr thresholded
DROP TABLE IF EXISTS spl_thresh;
CREATE TABLE spl_thresh (
  src INTEGER,
  dest INTEGER,
  prr REAL,
  len INTEGER);

--shortest paths: prr thresholded
DROP TABLE IF EXISTS sp_thresh_entry;
CREATE TABLE sp_thresh_entry (
  src INTEGER,
  dest INTEGER,
  prr REAL,
  f INTEGER,
  hop INTEGER);

--shortest path len with ETX
DROP TABLE IF EXISTS spl_etx;
CREATE TABLE spl_etx (
  src INTEGER,
  dest INTEGER,
  etx REAL);

--shortest path len entries with ETX
DROP TABLE IF EXISTS sp_etx_entry;
CREATE TABLE sp_etx_entry(
  src INTEGER,
  dest INTEGER,
  f INTEGER,
  hop INTEGER
);

SELECT "aggregating CX src,dest pairs (may take a while)";

DROP TABLE IF EXISTS mtl;
CREATE TABLE mtl AS
SELECT hc.src as src,
  hc.dest as dest,
  prr.prr as prr,
  hc.hc as hc
FROM 
(
  SELECT rx.src as src, 
    rx.dest as dest, 
    avg(hc) as hc
  FROM rx
  GROUP BY src, dest) as hc
JOIN 
(
  SELECT rxr.src as src,
    rxr.dest as dest,
    avg(received) as prr
  FROM rxr 
  GROUP BY src, dest
) as prr
ON prr.src=hc.src and prr.dest=hc.dest;


select "computing forwarder sets (may take a while)";
DROP TABLE IF EXISTS CXFS;
CREATE TABLE CXFS AS
SELECT 
  sd.src as src,
  sd.dest as dest,
  sf.dest as f,
  bw_opt.bw as bw
FROM mtl as sd
JOIN mtl as sf
  ON sd.src = sf.src
JOIN mtl as df
  ON sd.dest=df.src
  AND df.dest=sf.dest
JOIN (SELECT 0 as bw UNION select 0.5 as bw UNION select 1 as bw UNION select 2 as bw) as
bw_opt
WHERE sf.hc + df.hc <= sd.hc +bw_opt.bw
UNION
SELECT src, dest, f, bw FROM
( select sd.src as src, sd.dest as dest, sd.src as f
FROM mtl as sd
UNION select sd.src as src, sd.dest as dest, sd.dest as f
FROM mtl as sd) as source_and_dest
JOIN (SELECT 0 as bw UNION select 0.5 as bw UNION select 1 as bw UNION select 2 as bw) as bw_opt; 

EOF

echo "Computing single-path routes"

python sp.py $db
