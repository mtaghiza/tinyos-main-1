#!/bin/bash
set -x
sd=fig_scripts
outDir=output/tmp

max1Large=dbg/db/lpb.0x8D.1.1.mid.2.70.1348420808.db
floodDb=dbg_0921/db/lpf.0x8D.1.mid.1348192590.shortened.db


R --no-save --slave --args \
  -f $max1Large max_1_l \
  --png $outDir/fwd_v_sel_bw1.png \
  --xmin 0 \
  --xmax 60 \
  < $sd/fwd_cdf.R

R --no-save --slave  --args \
  -f $floodDb flood \
  -f $max1Large max_1_l \
  --png $outDir/prr_v_sel_bw1.png \
  < $sd/prr_cdf.R

R --no-save --slave  --args \
  -nf $floodDb flood \
  -f $max1Large max_1_l \
  --png $outDir/improvement_v_sel_bw1.png \
  < $sd/duty_cycle_improvement_cdf.R
