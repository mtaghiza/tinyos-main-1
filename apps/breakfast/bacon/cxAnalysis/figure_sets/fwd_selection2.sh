#!/bin/bash
set -x
sd=fig_scripts
outDir=output/fwd_selection2

last0Large=dbg/db/lpb.0x8D.1.0.mid.0.70.1348167022.db
max0Large=dbg/db/lpb.0x8D.1.0.mid.2.70.1348163370.db

last3Large=dbg/db/lpb.0x8D.1.3.mid.0.70.1348188938.db
avg3Large=dbg/db/lpb.0x8D.1.3.mid.1.70.1348181632.db
max3Large=dbg/db/lpb.0x8D.1.3.mid.2.70.1348185285.db
floodDb=dbg/db/lpf.0x8D.1.mid.1348192590.shortened.db

#selection method, buffer width, and overhead

R --no-save --slave --args \
  -f $last0Large last_0_l \
  -f $max0Large max_0_l \
  --xmin 0 \
  --xmax 50 \
  --png $outDir/fwd_v_sel_bw0.png \
  < $sd/fwd_cdf.R

R --no-save --slave --args \
  -f $last3Large last_3_l \
  -f $avg3Large avg_3_l \
  -f $max3Large max_3_l \
  --xmin 3 \
  --xmax 60 \
  --png $outDir/fwd_v_sel_bw3.png \
  < $sd/fwd_cdf.R

#compare fixed fwd selection method, vary buffer width
R --no-save --slave  --args \
  -f $floodDb flood \
  -f $last3Large last_3_l \
  -f $avg3Large avg_3_l \
  -f $max3Large max_3_l \
  --png $outDir/prr_v_sel_bw3.png \
  < $sd/prr_cdf.R

R --no-save --slave  --args \
  -f $floodDb flood \
  -f $last3Large last_3_l \
  -f $avg3Large avg_3_l \
  -f $max3Large max_3_l \
  --png $outDir/dc_v_sel_bw3.png \
  < $sd/duty_cycle_cdf.R


R --no-save --slave  --args \
  -f $floodDb flood \
  -f $last0Large last_0_l \
  -f $max0Large max_0_l \
  --png $outDir/prr_v_sel_bw0.png \
  < $sd/prr_cdf.R

R --no-save --slave  --args \
  -f $floodDb flood \
  -f $last0Large last_0_l \
  -f $max0Large max_0_l \
  --png $outDir/dc_v_sel_bw0.png \
  < $sd/duty_cycle_cdf.R

R --no-save --slave  --args \
  -nf $floodDb flood \
  -f $last0Large last_0_l \
  -f $max0Large max_0_l \
  --png $outDir/improvement_v_sel_bw0.png \
  < $sd/duty_cycle_improvement_cdf.R

R --no-save --slave  --args \
  -nf $floodDb flood \
  -f $last3Large last_3_l \
  -f $avg3Large avg_3_l \
  -f $max3Large max_3_l \
  --png $outDir/improvement_v_sel_bw3.png \
  < $sd/duty_cycle_improvement_cdf.R
