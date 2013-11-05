#!/bin/bash
if [ $# -lt 3 ]
then
  echo "$0 tests log db" 1>&2
  exit 1
fi

tests=$1
log=$2
db=$3

dos2unix $tests
dos2unix $log

cat $tests $log | sort -n -k 1 > tmp.combined

pv tmp.combined | awk '/SETUP_START/{print $0}' | cut -d ' ' -f 2 --complement > tmp.setup
pv tmp.combined | awk '/TRIAL/{print $0}' | cut -d ' ' -f 2 --complement > tmp.trial

pv tmp.combined | awk '/TRIAL/{trialNum=$1}/ TX /{print $1, $2, $5, trialNum}' > tmp.tx
pv tmp.combined | awk '/SETUP_START/{dest=$5}/TRIAL/{trialNum=$1}($2 == dest && $3== "RX"){print $1, $2, $4, $5, $6, $7, $8, trialNum}' > tmp.rx

sqlite3 $db <<EOF
.separator ' '

DROP TABLE IF EXISTS setup;
CREATE TABLE SETUP (
  sts REAL,
  type TEXT,
  src INTEGER,
  dest INTEGER,
  f REAL);
.import tmp.setup setup

DROP TABLE IF EXISTS trial;
CREATE TABLE trial (
  tts REAL,
  sts REAL,
  node INTEGER,
  role TEXT);
.import tmp.trial trial

DROP TABLE IF EXISTS r_tx;
CREATE TABLE r_tx (
  ts REAL,
  src INTEGER,
  sn INTEGER,
  tts REAL);
.import tmp.tx r_tx

DROP TABLE IF EXISTS r_rx;
CREATE TABLE r_rx (
  ts REAL,
  dest INTEGER,
  src INTEGER,
  sn INTEGER,
  hc INTEGER,
  rssi INTEGER,
  lqi INTEGER,
  tts REAL);
.import tmp.rx r_rx

DROP TABLE IF EXISTS trial_agg;
CREATE TABLE trial_agg AS
SELECT tx_agg.tts, 
  tx_agg.txc as txc,
  coalesce(rx_agg.rxc, 0) as rxc,
  coalesce(rx_agg.hc, 0) as hc,
  1.0*coalesce(rx_agg.rxc,0)/txc as prr
FROM (
  SELECT tts, count(*) as txc
  FROM r_tx 
  GROUP BY tts
) as tx_agg
LEFT JOIN (
  SELECT tts, count(*) as rxc, avg(hc) as hc
  FROM r_rx
  GROUP BY tts
) as rx_agg
ON rx_agg.tts = tx_agg.tts;

DROP TABLE IF EXISTS trial_agg;
CREATE TABLE trial_agg AS
SELECT tx_agg.tts, 
  1.0*tx_agg.txc as txc,
  1.0*coalesce(rx_agg.rxc, 0) as rxc,
  1.0*coalesce(rx_agg.hc, 0) as hc,
  1.0*coalesce(rx_agg.rxc,0)/txc as prr
FROM (
  SELECT tts, count(*) as txc
  FROM r_tx 
  GROUP BY tts
) as tx_agg
LEFT JOIN (
  SELECT tts, count(*) as rxc, avg(hc) as hc
  FROM r_rx
  GROUP BY tts
) as rx_agg
ON rx_agg.tts = tx_agg.tts;

DROP TABLE IF EXISTS setup_agg;
CREATE TABLE setup_agg AS
SELECT setup.type as type, 
  setup.src as src, 
  setup.dest as dest, 
  setup.f as f, 
  sum(rxc)/sum(txc) as prr,
  avg(hc) as hc
FROM trial_agg 
JOIN trial ON 
  trial_agg.tts = trial.tts 
JOIN setup ON 
  trial.sts = setup.sts 
GROUP BY setup.type, 
  setup.src, 
  setup.dest, 
  setup.f 
ORDER by src, dest, type;

-- This is the data we need to plot
DROP TABLE IF EXISTS reliability_final;
CREATE TABLE reliability_final AS
SELECT type, mtl.src, mtl.dest, f, 
  mtl.prr - setup_agg.prr as deltaPRR, 
  mtl.hc - setup_agg.hc as deltaHC,
  setup_agg.prr as testPRR,
  setup_agg.hc as testHC,
  mtl.hc as floodHC
FROM setup_agg
JOIN mtl on setup_agg.src=mtl.src and setup_agg.dest=mtl.dest
ORDER BY testPRR;

EOF
