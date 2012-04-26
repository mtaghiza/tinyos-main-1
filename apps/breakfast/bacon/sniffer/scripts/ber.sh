#!/bin/bash

f=$1
db=$1.db
tf=$(tempfile)

tail --lines=+2 $f > $tf
sqlite3 $db <<EOF
DROP TABLE IF EXISTS BER_STATS;
CREATE TABLE BER_STATS (
  sr INTEGER,
  txp INTEGER,
  delay INTEGER,
  ber REAL,
  crc_err REAL,
  prr_all REAL,
  prr_passed REAL);

.separator ' '
.import $tf BER_STATS

ALTER TABLE BER_STATS ADD COLUMN delayUS REAL;
UPDATE BER_STATS SET delayUS=1000000.0*(delay/32.0)*(1.0/sr);
EOF
