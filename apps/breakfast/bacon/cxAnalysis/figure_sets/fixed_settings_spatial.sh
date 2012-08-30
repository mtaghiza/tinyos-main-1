#!/bin/bash
#hey, run this from the vis directory

dbDir=../../cxActiveMessage/data/0825/db
floodDb=../../cxActiveMessage/data/0825/db/nsfb_f_all_1_0.40.db
connDb=../data/0824.log.db
outDir=fixed_settings

set -x
#single-path distance (ids)
python TestbedMap.py $connDb --simple 0 0.95 --distanceLabels 0 --outFile $outDir/connectivity_id.png
#single-path distance (depths)
python TestbedMap.py $connDb --simple 0 0.95 --distanceLabels 1 --outFile $outDir/connectivity_distance.png

#distance from root
python TestbedMap.py $floodDb --cxd --from 0 --outFile $outDir/flood_distance_rl.png
#distance to root
python TestbedMap.py $floodDb --cxd --to 0 --outFile $outDir/flood_distance_lr.png 

#prr from root
python TestbedMap.py $floodDb --cxp --from 0 --outFile $outDir/flood_prr_rl.png
#prr to root
python TestbedMap.py $floodDb --cxp --to 0 --outFile $outDir/flood_prr_lr.png

#buffer width effect: PRR to root
python TestbedMap.py $dbDir/nsfb_ub_all_1_0.40.db --cxp --to 0 --outFile $outDir/ub_bw_0.png
python TestbedMap.py $dbDir/nsfb_ub_all_1_1.40.db --cxp --to 0 --outFile $outDir/ub_bw_1.png
python TestbedMap.py $dbDir/nsfb_ub_all_1_3.40.db --cxp --to 0 --outFile $outDir/ub_bw_3.png
python TestbedMap.py $dbDir/nsfb_ub_all_1_5.41.db --cxp --to 0 --outFile $outDir/ub_bw_5.png

#forwarder selection by node
python TestbedMap.py $dbDir/nsfb_ub_all_1_0.40.db \
  --cxf 1 0 \
  --outFile $outDir/ub_f_by_node_adjacent.png
python TestbedMap.py $dbDir/nsfb_ub_all_1_0.40.db \
  --cxf 42 0 \
  --outFile $outDir/ub_f_by_node_mid.png
python TestbedMap.py $dbDir/nsfb_ub_all_1_0.40.db \
  --cxf 47 0 \
  --outFile $outDir/ub_f_by_node_far.png

#forwarder selection by buffer width

python TestbedMap.py $dbDir/nsfb_ub_all_1_0.40.db \
  --cxf 1 0 \
  --outFile $outDir/ub_f_by_bw_0.png
python TestbedMap.py $dbDir/nsfb_ub_all_1_1.40.db \
  --cxf 1 0 \
  --outFile $outDir/ub_f_by_bw_1.png
python TestbedMap.py $dbDir/nsfb_ub_all_1_3.40.db \
  --cxf 1 0 \
  --outFile $outDir/ub_f_by_bw_3.png
python TestbedMap.py $dbDir/nsfb_ub_all_1_5.41.db \
  --cxf 1 0 \
  --outFile $outDir/ub_f_by_bw_5.png

#duty cycle maps
#flood
python TestbedMap.py $floodDb \
  --dc \
  --outFile $outDir/flood_dc.png
#buffer width 0
python TestbedMap.py $dbDir/nsfb_ub_all_1_0.40.db \
  --dc \
  --outFile $outDir/burst_dc_0.png
#buffer width 1
python TestbedMap.py $dbDir/nsfb_ub_all_1_1.40.db \
  --dc \
  --outFile $outDir/burst_dc_1.png
#buffer width 5
python TestbedMap.py $dbDir/nsfb_ub_all_1_5.41.db \
  --dc \
  --outFile $outDir/burst_dc_5.png
