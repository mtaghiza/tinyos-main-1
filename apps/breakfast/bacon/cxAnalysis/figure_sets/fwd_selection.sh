#!/bin/bash
set -x
sd=fig_scripts
outDir=output/fwd_selection

avg0Small=data/cx/fwd_selection/db/lpb.0x8D.1.0.mid.1.3.1348007434.db
avg0Large=data/cx/fwd_selection/db/lpb.0x8D.1.0.mid.1.70.1348011086.db

avg1Small=data/cx/fwd_selection/db/lpb.0x8D.1.1.mid.1.3.1348022043.db
avg1Large=data/cx/fwd_selection/db/lpb.0x8D.1.1.mid.1.70.1348025695.db

avg3Small=data/cx/fwd_selection/db/lpb.0x8D.1.3.mid.1.3.1348036654.db
avg3Large=data/cx/fwd_selection/db/lpb.0x8D.1.3.mid.1.70.1348040306.db

max0Small=data/cx/fwd_selection/db/lpb.0x8D.1.0.mid.2.3.1348014738.db
max0Large=data/cx/fwd_selection/db/lpb.0x8D.1.0.mid.2.70.1348018390.db

max1Small=data/cx/fwd_selection/db/lpb.0x8D.1.1.mid.2.3.1348029347.db
max1Large=data/cx/fwd_selection/db/lpb.0x8D.1.1.mid.2.70.1348033000.db

max3Small=data/cx/fwd_selection/db/lpb.0x8D.1.3.mid.2.3.1348043958.db
max3Large=data/cx/fwd_selection/db/lpb.0x8D.1.3.mid.2.70.1348047610.db

floodDb=data/cx/fwd_selection/db/lpf.0x8D.1.mid.1348051263.db
#selection method, buffer width, and overhead

#compare fixed fwd selection method, vary buffer width
# OK, well these all work quite poorly.
R --no-save --slave  --args \
  -f $floodDb flood \
  -f $avg0Large avg_0_l \
  -f $avg1Large avg_1_l \
  -f $avg3Large avg_3_l \
  --png $outDir/prr_v_bw_avg_l.png \
  < $sd/prr_cdf.R

R --no-save --slave  --args \
  -f $floodDb flood \
  -f $max0Large max_0_l \
  -f $max1Large max_1_l \
  -f $max3Large max_3_l \
  --png $outDir/prr_v_bw_max_l.png \
  < $sd/prr_cdf.R


#TODO compare different fwd selection at fixed buffer width

#TODO compare fixed fwd selecfwd table
