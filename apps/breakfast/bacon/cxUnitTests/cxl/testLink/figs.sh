#!/bin/bash
db=$1

R --no-save --slave --args\
  --db $db \
  --plotBW 0 \
  --filter sp\
  --plotType absolute \
  --pdf fig/prr_v_failrate_absolute_pres_sp.pdf \
  < R/reliability.R

R --no-save --slave --args\
  --db $db \
  --plotBW 0 \
  --plotType absolute \
  --pdf fig/prr_v_failrate_absolute_pres.pdf \
  < R/reliability.R

exit 0

R --no-save --slave --args\
  --db $db \
  --plotType size \
  --pdf fig/sp_v_fs_size.pdf \
  < R/fss_v_spl.R

R --no-save --slave --args\
  --db $db \
  --plotType sizeHist \
  --pdf fig/sp_v_fs_size_hist.pdf \
  < R/fss_v_spl.R
  
R --no-save --slave --args\
  --db $db \
  --plotType length \
  --pdf fig/sp_v_fs_length.pdf \
  < R/fss_v_spl.R
  
R --no-save --slave --args\
  --db $db \
  --plotType lengthHist \
  --pdf fig/sp_v_fs_length_hist.pdf \
  < R/fss_v_spl.R

R --no-save --slave --args\
  --db $db \
  --plotType normalized\
  --pdf fig/prr_v_failrate_normalized.pdf \
  < R/reliability.R

R --no-save --slave --args\
  --db $db \
  --plotType absolute\
  --pdf fig/prr_v_failrate_absolute.pdf \
  < R/reliability.R
