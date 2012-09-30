#!/bin/bash
sd=fig_scripts
outDir=output/threshold
dataDir=data/cx/flood_threshold/db


options=""
for fn in $dataDir/*
do
  bn=$(basename $fn)
  thresh=$(echo "$bn" | cut -d '.' -f 3)
  options="$options --db $fn $thresh"
done
single90=data/cx/flood_threshold/db/flood.thresh.-90.1.1348942207.db
single100=data/cx/flood_threshold/db/flood.thresh.-100.1.1348945953.db

#normal "slow" tests
flood90=data/cx/capVSenders_retest/db/lpf.0x8D.1.mid.-90.1348678241.db
#flood90=data/cx/capVSenders_retest/db/lpf.0x8D.1.mid.-90.1348699695.db
flood80=data/cx/capVSenders_retest/db/lpf.0x8D.1.mid.-80.1348681893.db
flood70=data/cx/capVSenders_retest/db/lpf.0x8D.1.mid.-70.1348672717.db
flood100=data/cx/fwd_selection_0923/db/lpf.0x8D.1.mid.1348468231.db
set -x 

R --no-save --slave --args \
  --db $flood100 -100\
  --db $flood90 -90\
  --db $flood80 -80\
  --db $flood70 -70 \
  --png $outDir/prr_v_thresh_orig.png \
  < $sd/prr_cdf_ggplot.R

R --no-save --slave --args\
  $options \
  --png $outDir/prr_v_thresh.png \
  < $sd/prr_cdf_ggplot.R

R --no-save --slave --args\
  --db $single90 -90 \
  --db $single100 -100\
  --png $outDir/prr_v_thresh_single.png \
  < $sd/prr_cdf_ggplot.R

R --no-save --slave --args\
  --labels thresh \
  --db $single90 -90 \
  --db $single100 -100\
  --png $outDir/stability_v_thresh_single.png \
  < $sd/depth_comparison_distribution.R

R --no-save --slave --args\
  --labels thresh \
  $options\
  --png $outDir/stability_v_thresh.png \
  < $sd/depth_comparison_distribution.R

exit 0
#These are the original settings used
last2Large=data/cx/0924/db/lpb.0x8D.1.2.mid.0.70.1348528565.db
avg2Large=data/cx/0924/db/lpb.0x8D.1.2.mid.1.70.1348532217.db
max2Large=data/cx/0924/db/lpb.0x8D.1.2.mid.2.70.1348524913.db

last70=data/cx/capVSenders_threshold/db/lpb.0x8D.2.mid.0.70.-70.1348654875.db
last80=data/cx/capVSenders_threshold/db/lpb.0x8D.2.mid.0.70.-80.1348640319.db
avg70=data/cx/capVSenders_threshold/db/lpb.0x8D.2.mid.1.70.-70.1348658527.db
avg80=data/cx/capVSenders_threshold/db/lpb.0x8D.2.mid.1.70.-80.1348643971.db
max70=data/cx/capVSenders_threshold/db/lpb.0x8D.2.mid.2.70.-70.1348651223.db
max80=data/cx/capVSenders_threshold/db/lpb.0x8D.2.mid.2.70.-80.1348636667.db

flood90=data/cx/capVSenders_retest/db/lpf.0x8D.1.mid.-90.1348678241.db
#flood90=data/cx/capVSenders_retest/db/lpf.0x8D.1.mid.-90.1348699695.db
flood80=data/cx/capVSenders_retest/db/lpf.0x8D.1.mid.-80.1348681893.db
flood70=data/cx/capVSenders_retest/db/lpf.0x8D.1.mid.-70.1348672717.db
flood100=data/cx/fwd_selection_0923/db/lpf.0x8D.1.mid.1348468231.db

R --no-save --slave  --args \
  -f $last70 last_70 \
  -f $last80 last_80 \
  -f $last2Large last_100 \
  --png $outDir/prr_v_threshold_last.png \
  < $sd/prr_cdf.R

R --no-save --slave  --args \
  -f $avg70 avg_70 \
  -f $avg80 avg_80 \
  -f $avg2Large avg_100 \
  --png $outDir/prr_v_threshold_avg.png \
  < $sd/prr_cdf.R

R --no-save --slave  --args \
  -f $max70 max_70 \
  -f $max80 max_80 \
  -f $max2Large max_100 \
  --png $outDir/prr_v_threshold_max.png \
  < $sd/prr_cdf.R

R --no-save --slave --args \
  -f $flood90 flood_90 \
  -f $flood100 flood_100 \
  --png $outDir/prr_v_threshold_flood.png \
  < $sd/prr_cdf.R

R --no-save --slave --args \
  -f $flood70 \
  --png $outDir/stability_70.png \
  < $sd/asym_boxplot.R

R --no-save --slave --args \
  -f $flood80 \
  --png $outDir/stability_80.png \
  < $sd/asym_boxplot.R

R --no-save --slave --args \
  -f $flood90 \
  --png $outDir/stability_90.png \
  < $sd/asym_boxplot.R

R --no-save --slave --args \
  -f $flood100 \
  --png $outDir/stability_100.png \
  < $sd/asym_boxplot.R

R --no-save --slave --args\
  -f $flood100 \
  -n 36 \
  --ymax 7 \
  --png $outDir/depth_v_time_100.png \
  < $sd/depth_v_time_for_node.R

R --no-save --slave --args\
  -f $flood90 \
  -n 36 \
  --ymax 7 \
  --png $outDir/depth_v_time_90.png \
  < $sd/depth_v_time_for_node.R

R --no-save --slave --args \
  -f $flood90 \
  --png $outDir/asym_90.png\
  < $sd/flood_depth_asym.R

R --no-save --slave --args \
  -f $flood100 \
  --png $outDir/asym_100.png\
  < $sd/flood_depth_asym.R
