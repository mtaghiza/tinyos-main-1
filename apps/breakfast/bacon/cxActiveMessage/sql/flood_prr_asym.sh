#!/bin/bash
db=$1
#sqlite3 db/nsfb_f_all_1_0.db < sql/flood_prr_asym.sql
sqlite3 $db < sql/flood_prr_asym.sql
