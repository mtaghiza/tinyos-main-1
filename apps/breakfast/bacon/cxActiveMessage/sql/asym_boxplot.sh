#!/bin/bash
db=$1
#sqlite3 db/nsfb_f_all_1_0.db < sql/asym_boxplot.sql
sqlite3 $db < sql/asym_boxplot.sql
