#!/bin/bash
sqlite3 db/nsfb_f_all_1_0.db <<EOF
.mode csv
SELECT ts, 
  depth 
FROM rx_all 
WHERE src = 35 AND dest = 0 
ORDER BY ts;
EOF
