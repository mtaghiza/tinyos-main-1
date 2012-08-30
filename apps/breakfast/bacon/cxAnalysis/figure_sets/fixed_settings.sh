#!/bin/bash
dbDir=data/cx/0825/db
floodDb=data/cx/0825/db/nsfb_f_all_1_0.40.db
connDb=data/conn/all.log.db
sd=fig_scripts
outDir=output/fixed_settings

set -x
R --no-save --slave --args -f $dbDir/nsfb_f_all_1_0.40.db \
  --png $outDir/asym_boxplot.png \
  < $sd/asym_boxplot.R

R --no-save --slave --args -f $dbDir/nsfb_f_all_1_0.40.db \
  --png $outDir/flood_depth_asym.png \
  < $sd/flood_depth_asym.R

R --no-save --slave --args -f $dbDir/nsfb_f_all_1_0.40.db \
  --png $outDir/asym_boxplot.png \
  < $sd/asym_boxplot.R

R --no-save --slave --args -f $dbDir/nsfb_f_all_1_0.40.db \
  --png $outDir/depth_v_time_35.png \
  < $sd/depth_v_time_35.R

R --no-save --slave --args -f $dbDir/nsfb_f_all_1_0.40.db \
  --png $outDir/flood_prr_asym.png \
  < $sd/flood_prr_asym.R

R --no-save --slave --args \
  -f $dbDir/nsfb_f_all_1_0.40.db 1 \
  -f $dbDir/nsfb_f_all_2_0.40.db 2 \
  -f $dbDir/nsfb_f_all_3_0.40.db 3 \
  --png $outDir/flood_retx.png \
  < $sd/flood_retx.R

R --no-save --slave --args \
  -f $dbDir/nsfb_ub_all_1_0.40.db 1 \
  -f $dbDir/nsfb_ub_all_2_0.40.db 2 \
  -f $dbDir/nsfb_ub_all_3_0.40.db 3 \
  --png $outDir/ub_retx_0.png \
  < $sd/ub_retx.R

R --no-save --slave --args \
  -f $dbDir/nsfb_ub_all_1_1.40.db 1 \
  -f $dbDir/nsfb_ub_all_2_1.40.db 2 \
  -f $dbDir/nsfb_ub_all_3_1.40.db 3 \
  --png $outDir/ub_retx_1.png \
  < $sd/ub_retx.R

R --no-save --slave --args \
  -f $dbDir/nsfb_ub_all_1_0.40.db 0 \
  -f $dbDir/nsfb_ub_all_1_1.40.db 1 \
  -f $dbDir/nsfb_ub_all_1_3.40.db 3 \
  -f $dbDir/nsfb_ub_all_1_5.41.db 5 \
  --png $outDir/ub_bw.png \
  < $sd/ub_bw.R

R --no-save --slave  --args \
  -nf $dbDir/nsfb_f_all_1_0.40.db flood \
  -f $dbDir/nsfb_ub_all_1_0.40.db ub_0 \
  -f $dbDir/nsfb_ub_all_1_1.40.db ub_1 \
  -f $dbDir/nsfb_ub_all_1_3.40.db ub_3 \
  -f $dbDir/nsfb_ub_all_1_5.41.db ub_5 \
  --png $outDir/duty_cycle_improvement_cdf.png \
  < $sd/duty_cycle_improvement_cdf.R

R --no-save --slave  --args \
  -f $dbDir/nsfb_f_all_1_0.40.db flood \
  -f $dbDir/nsfb_ub_all_1_0.40.db ub_0 \
  -f $dbDir/nsfb_ub_all_1_1.40.db ub_1 \
  -f $dbDir/nsfb_ub_all_1_3.40.db ub_3 \
  -f $dbDir/nsfb_ub_all_1_5.41.db ub_5 \
  --png $outDir/duty_cycle_cdf.png \
  < $sd/duty_cycle_cdf.R

#single-path distance (ids)
python $sd/TestbedMap.py $connDb --simple 0 0.95 --distanceLabels 0 --outFile $outDir/connectivity_id.png
#single-path distance (depths)
python $sd/TestbedMap.py $connDb --simple 0 0.95 --distanceLabels 1 --outFile $outDir/connectivity_distance.png

#distance from root
python $sd/TestbedMap.py $floodDb --cxd --from 0 --outFile $outDir/flood_distance_rl.png
#distance to root
python $sd/TestbedMap.py $floodDb --cxd --to 0 --outFile $outDir/flood_distance_lr.png 

#prr from root
python $sd/TestbedMap.py $floodDb --cxp --from 0 --outFile $outDir/flood_prr_rl.png
#prr to root
python $sd/TestbedMap.py $floodDb --cxp --to 0 --outFile $outDir/flood_prr_lr.png

#buffer width effect: PRR to root
python $sd/TestbedMap.py $dbDir/nsfb_ub_all_1_0.40.db --cxp --to 0 --outFile $outDir/ub_bw_0.png
python $sd/TestbedMap.py $dbDir/nsfb_ub_all_1_1.40.db --cxp --to 0 --outFile $outDir/ub_bw_1.png
python $sd/TestbedMap.py $dbDir/nsfb_ub_all_1_3.40.db --cxp --to 0 --outFile $outDir/ub_bw_3.png
python $sd/TestbedMap.py $dbDir/nsfb_ub_all_1_5.41.db --cxp --to 0 --outFile $outDir/ub_bw_5.png

#forwarder selection by node
python $sd/TestbedMap.py $dbDir/nsfb_ub_all_1_0.40.db \
  --cxf 1 0 \
  --outFile $outDir/ub_f_by_node_adjacent.png
python $sd/TestbedMap.py $dbDir/nsfb_ub_all_1_0.40.db \
  --cxf 42 0 \
  --outFile $outDir/ub_f_by_node_mid.png
python $sd/TestbedMap.py $dbDir/nsfb_ub_all_1_0.40.db \
  --cxf 47 0 \
  --outFile $outDir/ub_f_by_node_far.png

#forwarder selection by buffer width

python $sd/TestbedMap.py $dbDir/nsfb_ub_all_1_0.40.db \
  --cxf 1 0 \
  --outFile $outDir/ub_f_by_bw_0.png
python $sd/TestbedMap.py $dbDir/nsfb_ub_all_1_1.40.db \
  --cxf 1 0 \
  --outFile $outDir/ub_f_by_bw_1.png
python $sd/TestbedMap.py $dbDir/nsfb_ub_all_1_3.40.db \
  --cxf 1 0 \
  --outFile $outDir/ub_f_by_bw_3.png
python $sd/TestbedMap.py $dbDir/nsfb_ub_all_1_5.41.db \
  --cxf 1 0 \
  --outFile $outDir/ub_f_by_bw_5.png

#duty cycle maps
#flood
python $sd/TestbedMap.py $floodDb \
  --dc \
  --outFile $outDir/flood_dc.png
#buffer width 0
python $sd/TestbedMap.py $dbDir/nsfb_ub_all_1_0.40.db \
  --dc \
  --outFile $outDir/burst_dc_0.png
#buffer width 1
python $sd/TestbedMap.py $dbDir/nsfb_ub_all_1_1.40.db \
  --dc \
  --outFile $outDir/burst_dc_1.png
#buffer width 5
python $sd/TestbedMap.py $dbDir/nsfb_ub_all_1_5.41.db \
  --dc \
  --outFile $outDir/burst_dc_5.png
