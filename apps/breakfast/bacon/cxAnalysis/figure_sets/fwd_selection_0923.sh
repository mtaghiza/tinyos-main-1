#!/bin/bash
sd=fig_scripts
outDir=output/fwd_selection_0923

last0Large=data/cx/fwd_selection_0923/db/lpb.0x8D.1.0.mid.0.70.1348449970.db
avg0Large=data/cx/fwd_selection_0923/db/lpb.0x8D.1.0.mid.1.70.1348453622.db
max0Large=data/cx/fwd_selection_0923/db/lpb.0x8D.1.0.mid.2.70.1348446317.db

last1Large=data/cx/fwd_selection_0923/db/lpb.0x8D.1.1.mid.0.70.1348439014.db
avg1Large=data/cx/fwd_selection_0923/db/lpb.0x8D.1.1.mid.1.70.1348442666.db
max1Large=data/cx/fwd_selection_0923/db/lpb.0x8D.1.1.mid.2.70.1348435362.db

last2Large=data/cx/0924/db/lpb.0x8D.1.2.mid.0.70.1348528565.db
#last2Large=data/cx/0924/db/lpb.0x8D.1.2.mid.0.70.1348576834.db
avg2Large=data/cx/0924/db/lpb.0x8D.1.2.mid.1.70.1348532217.db
#avg2Large=data/cx/0924/db/lpb.0x8D.1.2.mid.1.70.1348580487.db
max2Large=data/cx/0924/db/lpb.0x8D.1.2.mid.2.70.1348524913.db
#max2Large=data/cx/0924/db/lpb.0x8D.1.2.mid.2.70.1348573182.db


last2Small=data/cx/0924/db/lpb.0x8D.1.2.mid.0.3.1348539521.db
avg2Small=data/cx/0924/db/lpb.0x8D.1.2.mid.1.3.1348543173.db
max2Small=data/cx/0924/db/lpb.0x8D.1.2.mid.2.3.1348535869.db

last3Large=data/cx/fwd_selection_0923/db/lpb.0x8D.1.3.mid.0.70.1348460926.db
avg3Large=data/cx/fwd_selection_0923/db/lpb.0x8D.1.3.mid.1.70.1348464579.db
max3Large=data/cx/fwd_selection_0923/db/lpb.0x8D.1.3.mid.2.70.1348457274.db

floodDb=data/cx/fwd_selection_0923/db/lpf.0x8D.1.mid.1348468231.db

#retx tests

tx2Last0Small=data/cx/0924/db/lpb.0x8D.2.0.mid.0.3.1348554129.db
tx2Avg0Small=data/cx/0924/db/lpb.0x8D.2.0.mid.1.3.1348557781.db
tx2Max0Small=data/cx/0924/db/lpb.0x8D.2.0.mid.2.3.1348550478.db

connDb=data/conn/db/conn_0922.log.db

goodNoCapture=data/cx/0924/conditionalPRR_db/random.map.200nocap.1348513157.db
goodNoCapture1=data/cx/0924/conditionalPRR_db/deterministic.map.200nocap.1.1348520404.db
goodNoCapture2=data/cx/0924/conditionalPRR_db/deterministic.map.200nocap.2.1348569320.db
goodNoCapture3=data/cx/0924/conditionalPRR_db/deterministic.map.200nocap.3.1348521694.db
goodNoCapture4=data/cx/0924/conditionalPRR_db/deterministic.map.200nocap.4.1348522337.db
goodNoCapture5=data/cx/0924/conditionalPRR_db/deterministic.map.200nocap.5.1348571251.db
goodNoCapture6=data/cx/0924/conditionalPRR_db/deterministic.map.200nocap.6.1348523625.db
goodNoCapture7=data/cx/0924/conditionalPRR_db/deterministic.map.200nocap.7.1348524269.db


bad=data/cx/0925/conditionalPRR_db/map.200bad.1348600080.db
badCap=data/cx/0925/conditionalPRR_db/map.200bad.cap.1348600723.db
badNoCap=data/cx/0925/conditionalPRR_db/map.200bad.nocap.1348601367.db

goodCap10=data/cx/0925/conditionalPRR_db/map.200cap.10.1348596859.db
goodCap3=data/cx/0925/conditionalPRR_db/map.200cap.3.1348597504.db
goodCap4=data/cx/0925/conditionalPRR_db/map.200cap.4.1348598148.db
goodCap5=data/cx/0925/conditionalPRR_db/map.200cap.5.1348598792.db
goodCap7=data/cx/0925/conditionalPRR_db/map.200cap.7.1348599436.db

#second round
# last0large=data/cx/fwd_selection_0923/db/lpb.0x8D.1.0.mid.0.70.1348486492.db
# avg0large=data/cx/fwd_selection_0923/db/lpb.0x8D.1.0.mid.1.70.1348490144.db
# max0large=data/cx/fwd_selection_0923/db/lpb.0x8D.1.0.mid.2.70.1348482840.db
# 
# last1large=data/cx/fwd_selection_0923/db/lpb.0x8D.1.1.mid.0.70.1348475536.db
# avg1large=data/cx/fwd_selection_0923/db/lpb.0x8D.1.1.mid.1.70.1348479188.db
# max1large=data/cx/fwd_selection_0923/db/lpb.0x8D.1.1.mid.2.70.1348471884.db


  #duty cycle improvement
  R --no-save --slave  --args \
    -nf $floodDb flood \
    -f $max0Large max_0_l \
    -f $max1Large max_1_l \
    -f $max2Large max_2_l \
    -f $max3Large max_3_l \
    --png $outDir/improvement_v_bw.png \
    < $sd/duty_cycle_improvement_cdf.R

  #prr
  R --no-save --slave  --args \
    -f $floodDb flood \
    -f $max0Large max_0_l \
    -f $max1Large max_1_l \
    -f $max2Large max_2_l \
    -f $max3Large max_3_l \
    --png $outDir/prr_v_bw.png \
    < $sd/prr_cdf.R


exit 0

set -x

  #prr
  R --no-save --slave  --args \
    -f $floodDb flood \
    -f $last0Large last_0_l \
    -f $avg0Large avg_0_l \
    -f $max0Large max_0_l \
    -f $tx2Last0Small 2_last_0_s \
    -f $tx2Avg0Small 2_avg_0_s \
    -f $tx2Max0Small 2_max_0_s \
    --png $outDir/prr_v_retx_bw_0.png \
    < $sd/prr_cdf.R
  #duty cycle improvement
  R --no-save --slave  --args \
    -nf $floodDb flood \
    -f $last0Large last_0_l \
    -f $avg0Large avg_0_l \
    -f $max0Large max_0_l \
    -f $tx2Last0Small 2_last_0_s \
    -f $tx2Avg0Small 2_avg_0_s \
    -f $tx2Max0Small 2_max_0_s \
    --png $outDir/improvement_v_retx_bw_0.png \
    < $sd/duty_cycle_improvement_cdf.R

  #prr
  R --no-save --slave  --args \
    -f $floodDb flood \
    -f $avg2Large avg_2_l \
    -f $max2Large max_2_l \
    -f $avg2Small avg_2_s \
    -f $max2Small max_2_s \
    --png $outDir/prr_v_state_bw_2.png \
    < $sd/prr_cdf.R

  #duty cycle improvement
  R --no-save --slave  --args \
    -nf $floodDb flood \
    -f $avg2Large avg_2_l \
    -f $max2Large max_2_l \
    -f $avg2Small avg_2_s \
    -f $max2Small max_2_s \
    --png $outDir/improvement_v_state_bw_2.png \
    < $sd/duty_cycle_improvement_cdf.R

R --no-save --slave --args\
  -f $goodNoCapture \
  --png $outDir/rssi_v_senders.png \
  < $sd/rssi_v_senders.R


R --no-save --slave --args\
  -f $goodNoCapture good_no_capture \
  -f $goodCap3 cap_3 \
  -f $goodCap4 cap_4 \
  -f $goodCap5 cap_5 \
  -f $goodCap7 cap_7 \
  -f $goodCap10 cap_10 \
  --png $outDir/prr_capture.png \
  < $sd/prr_v_senders.R

R --no-save --slave --args\
  -f $bad bad \
  -f $badCap bad_cap \
  -f $badNoCap bad_no_cap \
  --png $outDir/prr_v_bad.png \
  < $sd/prr_v_senders.R

R --no-save --slave --args\
  -f $goodNoCapture good_no_capture \
  -f $goodNoCapture1 good_no_capture_1 \
  -f $goodNoCapture2 good_no_capture_2 \
  -f $goodNoCapture3 good_no_capture_3 \
  -f $goodNoCapture4 good_no_capture_4 \
  -f $goodNoCapture5 good_no_capture_5 \
  -f $goodNoCapture6 good_no_capture_6 \
  -f $goodNoCapture7 good_no_capture_7 \
  --png $outDir/prr_v_senders.png \
  < $sd/prr_v_senders.R


#37
R --no-save --slave --args\
  -f $floodDb \
  -n 37 \
  --png $outDir/depth_v_time_37.png \
  < $sd/depth_v_time_for_node.R

R --no-save --slave --args -f $floodDb \
  --png $outDir/flood_depth_asym.png \
  < $sd/flood_depth_asym.R

#effective of CX losses on network topology
simDepthCSV=$outDir/sim_depth.csv
floodDepthCSV=$outDir/flood_depth.csv

python fig_scripts/TestbedMap.py $connDb --fsd \
  --outFile $outDir/map_sim_depth.png \
  --text > $simDepthCSV

python fig_scripts/TestbedMap.py $floodDb --cxd \
  --outFile $outDir/map_flood_depth.png \
  --text > $floodDepthCSV

R --no-save --slave --args\
  -f $simDepthCSV sim \
  -f $floodDepthCSV flood \
  --png $outDir/depth_comparison.png \
  < $sd/depth_comparison.R

R --no-save --slave --args \
  -f $floodDb \
  --png $outDir/asym_boxplot.png \
  < $sd/asym_boxplot.R


# single-transmitter loss behavior
R --no-save --slave --args\
  -f $connDb \
  --png $outDir/prr_v_rssi.png \
  --xmin -100 \
  --xmax -40 \
  < $sd/prr_v_rssi.R


#fixed bw, vary selection method
for bw in 0 1 2 3
do
  lastName=last${bw}Large
  avgName=avg${bw}Large
  maxName=max${bw}Large
  
  # number of forwarders
  R --no-save --slave --args \
    -f ${!lastName} last_${bw}_l \
    -f ${!avgName} avg_${bw}_l \
    -f ${!maxName} max_${bw}_l \
    --xmin 0 \
    --xmax 60 \
    --png $outDir/fwd_v_sel_bw_${bw}.png \
    < $sd/fwd_cdf.R

  #prr
  R --no-save --slave  --args \
    -f $floodDb flood \
    -f ${!lastName} last_${bw}_l \
    -f ${!avgName} avg_${bw}_l \
    -f ${!maxName} max_${bw}_l \
    --png $outDir/prr_v_sel_bw_${bw}.png \
    < $sd/prr_cdf.R

  #duty cycle
  R --no-save --slave  --args \
    -f $floodDb flood \
    -f ${!lastName} last_${bw}_l \
    -f ${!avgName} avg_${bw}_l \
    -f ${!maxName} max_${bw}_l \
    --png $outDir/dc_v_sel_bw_${bw}.png \
    < $sd/duty_cycle_cdf.R

  #duty cycle improvement
  R --no-save --slave  --args \
    -nf $floodDb flood \
    -f ${!lastName} last_${bw}_l \
    -f ${!avgName} avg_${bw}_l \
    -f ${!maxName} max_${bw}_l \
    --png $outDir/improvement_v_sel_bw_${bw}.png \
    < $sd/duty_cycle_improvement_cdf.R
done

