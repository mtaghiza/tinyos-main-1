#!/bin/bash
outDir=dfMaster
sd=fig_scripts
mkdir -p $outDir/pdf

fileList=""

tbd=data_final
pd=data_final/125_fec/db

#simulation data
simDir=data_final/simulation/flood
simOptions=""
sim0Options=""
sim6Options=""
for f in $simDir/*-csv
do
  bn=$(basename $f)
  t=$(echo "$bn" | cut -d '-' -f 4)
  txp=$(echo "$bn" | cut -d '-' -f 6)
  ct=$(echo "$bn" | cut -d '-' -f 8)
  ncl=$(echo "$bn" | cut -d '-' -f 10)
  ncm=$(echo "$bn" | cut -d '-' -f 12)
  sl=$(echo "$bn" | cut -d '-' -f 14)

  simOptions="$simOptions --csv $f sim_${txp}_${t}"
  if [ "$txp" == "0x8D" ]
  then
    sim0Options="$sim0Options --csv $f sim_${txp}_${t}"
    fileList="$fileList $f"
  fi

  if [ "$txp" == "0x2D" ]
  then
    sim6Options="$sim6Options --csv $f sim_${txp}_${t}"
    fileList="$fileList $f"
  fi

done



#Phy Data
pFiles=$(find $pd -type f -name '*.db')
phyOptions=""
capture0Options=""
for f in $pFiles
do
  bn=$(basename $f)
  numHigh=$(echo $bn | cut -d '.' -f 3)
  captureMargin=$(echo $bn | cut -d '.' -f 4)
  numLow=$(echo $bn | cut -d '.' -f 7)
  sr=$(echo $bn | cut -d '.' -f 9)
  fecOn=$(echo $bn | cut -d '.' -f 11)
  if [ "$captureMargin" == "0" ]
  then
    capture0Options="$capture0Options --db $f $(($numHigh + $numLow)) $sr $fecOn $captureMargin $numHigh"    
  fi
  phyOptions="$phyOptions --db $f $(($numHigh + $numLow)) $sr $fecOn $captureMargin $numHigh"
  fileList="$fileList $f"
 
done

#root flood for distance measures
rf6Files=$(find $tbd -type f -name '*.db' | grep 'rootFlood' | grep '0x2D')

floodDistanceOptions=""
for f in $rf6Files
do
  floodDistanceOptions="$floodDistanceOptions --db $f rootFlood" 
  fileList="$fileList $f"
done

#fixed bw/selection method, vary txp
txpFiles=$(find $tbd -type f -name '*.db' | grep 'burst' | grep 'bw.2' | grep '61440' | grep 'rt.8')

txpOptions=""
txp0Options=""
txp6Options=""
txp12Options=""
for f in $txpFiles
do
  bn=$(basename $f)
  txp=$(echo "$bn" | cut -d '.' -f 8)
  txpOptions="$txpOptions --db $f $txp"
  case $txp in
    0x8D)
      txp0Options="$txp0Options --db $f $txp"
      fileList="$fileList $f"
      ;;
    0x2D)
      txp6Options="$txp6Options --db $f $txp"
      fileList="$fileList $f"
      ;;
    0x25)
      txp12Options="$txp12Options --db $f $txp"
      fileList="$fileList $f"
      ;;
    *)
    ;;
  esac
done


#Fixed bw/txp, vary selection method
#these files are for the DCI/PRR v. sel figures
sel0Tx6Files=$(find $tbd -type f -name '*.db' | grep 'burst' | grep 'bw.0' | grep '61440' |  grep '0x2D' | grep 'sel.0')
sel2Tx6Files=$(find $tbd -type f -name '*.db' | grep 'burst' | grep 'bw.0' | grep '61440' |  grep '0x2D' | grep 'sel.2')
sel3Tx6Files=$(find $tbd -type f -name '*.db' | grep 'burst' | grep 'bw.0' | grep '61440' |  grep '0x2D' | grep 'rt.8')

selOptions=""
for f in $sel0Tx6Files $sel2Tx6Files $sel3Tx6Files
do
  bn=$(basename $f)
  sel=$(echo $bn | cut -d '.' -f 6)
  selOptions="$selOptions --db $f $sel 1"
  fileList="$fileList $f"
done

#Fixed selection method/txp, vary bw
#these files are for the DCI/PRR v. bw figures: using last
# bw0Tx6Files=$(find $tbd -type f -name '*.db' | grep 'burst' | grep 'bw.0' | grep '61440' |  grep '0x2D' | grep 'sel.0')
# bw1Tx6Files=$(find $tbd -type f -name '*.db' | grep 'burst' | grep 'bw.1' | grep '61440' |  grep '0x2D' | grep 'sel.0')
# bw2Tx6Files=$(find $tbd -type f -name '*.db' | grep 'burst' | grep 'bw.2' | grep '61440' |  grep '0x2D' | grep 'sel.0')
# bw3Tx6Files=$(find $tbd -type f -name '*.db' | grep 'burst' | grep 'bw.3' | grep '61440' |  grep '0x2D' | grep 'sel.0')
# bw5Tx6Files=$(find $tbd -type f -name '*.db' | grep 'burst' | grep 'bw.5' | grep '61440' |  grep '0x2D' | grep 'sel.0')

#these files are for the DCI/PRR v. bw figures: using average
bw0Tx6Files=$(find $tbd -type f -name '*.db' | grep 'burst' | grep 'bw.0' | grep '61440' |  grep '0x2D' | grep 'rt.8')
bw1Tx6Files=$(find $tbd -type f -name '*.db' | grep 'burst' | grep 'bw.1' | grep '61440' |  grep '0x2D' | grep 'rt.8')
bw2Tx6Files=$(find $tbd -type f -name '*.db' | grep 'burst' | grep 'bw.2' | grep '61440' |  grep '0x2D' | grep 'rt.8')
bw3Tx6Files=$(find $tbd -type f -name '*.db' | grep 'burst' | grep 'bw.3' | grep '61440' |  grep '0x2D' | grep 'rt.8')
bw5Tx6Files=$(find $tbd -type f -name '*.db' | grep 'burst' | grep 'bw.5' | grep '61440' |  grep '0x2D' | grep 'rt.8')

bwOptions=""
for f in $bw0Tx6Files $bw1Tx6Files $bw2Tx6Files $bw3Tx6Files $bw5Tx6Files
do
  bn=$(basename $f)
  bw=$(echo $bn | cut -d '.' -f 4)
  bwOptions="$bwOptions --db $f $bw 1"
  fileList="$fileList $f"
done


#Flood results for normalization by txp
flood12Files=$(find $tbd -type f -name '*.db' | grep 'flood' | grep '61440' | grep '0x25')
flood6Files=$(find $tbd -type f -name '*.db' | grep 'flood' | grep '61440' | grep '0x2D')
flood0Files=$(find $tbd -type f -name '*.db' | grep 'flood' | grep '61440' | grep '0x8D')

flood12Options=""
for f in $flood12Files
do
  flood12Options="$flood12Options --ndb $f 0x25 0"
  fileList="$fileList $f"
done

flood6Options=""
for f in $flood6Files
do
  flood6Options="$flood6Options --ndb $f 0x2D 0"
  fileList="$fileList $f"
done

flood0Options=""
for f in $flood0Files
do
  flood0Options="$flood0Options --ndb $f 0x8D 0"
  fileList="$fileList $f"
done

#OK, options are all collected now.

function bw(){
  echo "PRR V. BW"
  R --no-save --slave --args \
    --dir lr \
    $bwOptions \
    --xmin 0.80 \
    --pdf $outDir/pdf/prr_v_bw.pdf \
    --labels bw\
    < $sd/prr_cdf_ggplot.R

  echo "DCI V. BW"
  R --no-save --slave --args \
    $bwOptions \
    $flood6Options \
    --pdf $outDir/pdf/dci_v_bw.pdf \
    --labels bw\
    --xmin 0 --xmax 1.25\
    < $sd/duty_cycle_improvement_cdf_ggplot.R
}

function sel(){
  echo "PRR V. Sel"
  R --no-save --slave --args \
    --dir lr \
    $selOptions \
    --pdf $outDir/pdf/prr_v_sel.pdf \
    --labels sel\
    < $sd/prr_cdf_ggplot.R

  echo "DCI V. Sel"
  R --no-save --slave --args \
    $selOptions \
    $flood6Options \
    --pdf $outDir/pdf/dci_v_sel.pdf \
    --labels sel\
    --xmin 0 --xmax 1.25\
    < $sd/duty_cycle_improvement_cdf_ggplot.R
}
function depthVTime(){
  echo "Depth V. Time"
  R --no-save --slave --args \
    -n 29 \
    --ymin 2 --ymax 6\
    $floodDistanceOptions \
    --pdf $outDir/pdf/depth_v_time_high.pdf \
    < $sd/depth_v_time_for_node.R
}

function floodDCHist(){
  echo "Flood DC Histogram"
  R --no-save --slave --args \
    $flood6Options \
    --xmin 0.02\
    --plotWidth 4\
    --plotHeight 2\
    --plotType hist\
    --pdf $outDir/pdf/dc_flood.pdf \
    < $sd/duty_cycle_cdf_ggplot.R
}

function floodPRRCDF(){
  echo "Flood PRR CDF"
  R --no-save --slave --args \
    --dir lr \
    $flood6Options \
    --labels flood \
    --xmin 0.85\
    --xmax 1.01\
    --plotHeight 2\
    --plotWidth 4\
    --plotType histogram\
    --pdf $outDir/pdf/prr_flood_hist.pdf \
    < $sd/prr_cdf_ggplot.R

  R --no-save --slave --args \
    --dir lr \
    $flood6Options \
    --labels flood \
    --xmin 0.85\
    --xmax 1.00\
    --plotType cdf\
    --pdf $outDir/pdf/prr_flood_cdf.pdf \
    < $sd/prr_cdf_ggplot.R
}

function xVTxp(){

  echo "DC V. Distance/TXP"
  R --no-save --slave --args \
    $txpOptions\
    --plotType scatter \
    --ymin 0.01\
    --ymax 0.04\
    --xmin 1\
    --size large\
    --pdf $outDir/pdf/dc_v_distance_txp_bw_2_scatter.pdf \
    < fig_scripts/dc_by_slot.R

  echo "Throughput V. Distance/TXP"
  R --no-save --slave --args \
    $txpOptions \
    --pdf $outDir/pdf/throughput_v_distance.pdf\
    < $sd/ipi_v_distance.R

  echo "Distance V TXP"
  R --no-save --slave --args \
    --labels txp \
    --removeOneHop 0\
    $flood0Options \
    $flood6Options \
    $flood12Options \
    --pdf $outDir/pdf/distance_v_txp.pdf\
    --sortLabel 0x25\
    < $sd/depth_comparison_distribution.R

  echo "DC V. Distance/TXP @0"
  R --no-save --slave --args \
    $txp0Options\
    --plotType scatter \
    --ymin 0.01\
    --ymax 0.04\
    --xmin 1 \
    --xmax 7 \
    --size small\
    --pdf $outDir/pdf/dc_v_distance_txp_0_bw_2_scatter.pdf \
    < fig_scripts/dc_by_slot.R

  echo "DC V. Distance/TXP @-6"
  R --no-save --slave --args \
    $txp6Options\
    --plotType scatter \
    --ymin 0.01\
    --ymax 0.04\
    --xmin 1 \
    --xmax 7 \
    --size small\
    --pdf $outDir/pdf/dc_v_distance_txp_6_bw_2_scatter.pdf \
    < fig_scripts/dc_by_slot.R

  echo "DC V. Distance/TXP @-12"
  R --no-save --slave --args \
    $txp12Options\
    --plotType scatter \
    --ymin 0.01\
    --ymax 0.04\
    --xmin 1 \
    --xmax 7 \
    --size small\
    --pdf $outDir/pdf/dc_v_distance_txp_12_bw_2_scatter.pdf \
    < fig_scripts/dc_by_slot.R
}

function dciVTxp(){
  echo "DCI @ 0"
  R --no-save --slave --args \
    $txp0Options \
    $flood0Options \
    --pdf $outDir/pdf/dci_at_0.pdf \
    --labels sel\
    --xmin 0 --xmax 1.25\
    < $sd/duty_cycle_improvement_cdf_ggplot.R

  echo "DCI @ -6"
  R --no-save --slave --args \
    $txp6Options \
    $flood6Options \
    --pdf $outDir/pdf/dci_at_6.pdf \
    --labels sel\
    --xmin 0 --xmax 1.25\
    < $sd/duty_cycle_improvement_cdf_ggplot.R

  echo "DCI @ -12"
  R --no-save --slave --args \
    $txp12Options \
    $flood12Options \
    --pdf $outDir/pdf/dci_at_12.pdf \
    --labels sel\
    --xmin 0 --xmax 1.25\
    < $sd/duty_cycle_improvement_cdf_ggplot.R
}

function phy(){
  echo "PRR V Senders"
  R --no-save --slave --args \
    $phyOptions \
    --plotType prrPass \
    --sr 125 \
    --aspect square\
    --pdf $outDir/pdf/prr_v_senders.pdf \
    < fig_scripts/fecBer_v_senders.R

  echo "BER V Senders"
  R --no-save --slave --args \
    $phyOptions \
    --plotType ber \
    --sr 125 \
    --aspect square\
    --pdf $outDir/pdf/ber_v_senders.pdf \
    < fig_scripts/fecBer_v_senders.R
  
  echo "RSSI V Senders"
  R --no-save --slave --args \
    $capture0Options \
    --aspect square\
    --pdf $outDir/pdf/rssi_v_senders.pdf\
    < fig_scripts/fecRssi_v_senders.R
}
function sim(){
  echo "Sim Distance"
  R --no-save --slave --args \
    --labels sim \
    --removeOneHop 1\
    --hideNaive 1\
    $flood6Options \
    $sim6Options \
    --pdf $outDir/pdf/distance_v_txp_sim_6.pdf\
    < fig_scripts/depth_comparison_distribution.R
}
function spatial(){
  f=data_final/testbed/avg_rounded_bw_db/type.burst.bw.0.sel.1.txp.0x2D.ipi.61440.thresh.-100.sm.map.nonroot.rt.8.tn.2.1350096028.db
  
  closeNode=1
  midNode=42
  farNode=46
  
  python fig_scripts/TestbedMap.py $f\
    --cxfs $farNode 0 2 \
    --labelAll 0\
    --bgImage 0\
    --outFile $outDir/map_far_snapshot_no_bg.pdf

  python fig_scripts/TestbedMap.py $f\
    --cxfs $farNode 0 2 \
    --labelAll 0\
    --bgImage 1\
    --outFile $outDir/map_far_snapshot.pdf

  python fig_scripts/TestbedMap.py $f\
    --cxfs $midNode 0 2 \
    --labelAll 0\
    --bgImage 0\
    --outFile $outDir/map_mid_snapshot_no_bg.pdf

  python fig_scripts/TestbedMap.py $f\
    --cxfs $midNode 0 2 \
    --labelAll 0\
    --bgImage 1\
    --outFile $outDir/map_mid_snapshot.pdf

  python fig_scripts/TestbedMap.py data_final/connectivity/1009.log.db \
    --simple \
    --txp 0x2D --pl 16 \
    --distanceLabels 1\
    --bgImage 1\
    --labelAll 0\
    --outFile $outDir/testbed_map.pdf
  
  python fig_scripts/TestbedMap.py $f\
    --cxf $midNode 0 \
    --labelAll 0\
    --bgImage 0\
    --outFile $outDir/map_mid.pdf
  
  python fig_scripts/TestbedMap.py $f\
    --cxf $closeNode 0 \
    --labelAll 0\
    --bgImage 0\
    --outFile $outDir/map_close.pdf
  
  
  python fig_scripts/TestbedMap.py $f\
    --cxf $farNode 0 \
    --labelAll 0\
    --bgImage 0\
    --outFile $outDir/map_far.png

  python fig_scripts/TestbedMap.py $f\
    --cxf $midNode 0 \
    --labelAll 0\
    --bgImage 1\
    --outFile $outDir/map_mid_bg.pdf

  python fig_scripts/TestbedMap.py $f\
    --cxf $farNode 0 \
    --labelAll 0\
    --bgImage 1\
    --outFile $outDir/map_far_bg.pdf
}

function extrapolation(){
  simDataDir=data_final/extrapolation/1014
  ipiOptions=""
  fwdOptions=""
  for f in $simDataDir/*fwdAgg.txt $simDataDir/*ipi.txt
  do
    bn=$(basename $f)
    t=$(echo $bn | rev | cut -d '.' -f 2 | rev)
    aspectRatio=$(echo $bn | cut -d '.' -f 2)
    density=$(echo $bn | cut -d '.' -f 4 | tr '-' '.')
    numNodes=$(echo $bn | cut -d '.' -f 6)
    dm=$(echo $bn | cut -d '.' -f 8)
    tn=$(echo $bn | cut -d '.' -f 9)
    if [ "$dm" == "ravg" ]
    then
      if [ "$aspectRatio" == "1" -o "$aspectRatio" == "4" ]
      then
        if [ "$t" == "ipi" ]
        then
          ipiOptions="$ipiOptions --txt $f $aspectRatio $density $numNodes"
        fi
        if [ "$t" == "fwdAgg" ]
        then
          fwdOptions="$fwdOptions --txt $f $aspectRatio $density $numNodes"
        fi
      fi
    fi
  done
  

  R --no-save --slave --args\
    $ipiOptions\
    --plotType diameter\
    --pdf $outDir/pdf/throughput_v_diameter.pdf\
    < $sd/sim_ipi.R
  
  R --no-save --slave --args\
    $fwdOptions \
    --plotType diameter\
    --pdf $outDir/pdf/active_v_diameter.pdf\
    < $sd/active_slots.R
}


function listFiles(){
  echo "$fileList"
}

function prr_v_dc(){
  R --no-save --slave \
    --args \
    --dir lr \
    $bwOptions \
    $flood6Options \
    --labels bw\
    --aggByLabel 1\
    --plotErrorBars 0\
    --pdf $outDir/pdf/prr_v_dc_agg.pdf\
    < $sd/prr_v_dc_scatter.R

  R --no-save --slave \
    --args \
    --dir lr \
    $bwOptions \
    $flood6Options \
    --labels bw\
    --aggByLabel 1\
    --plotErrorBars 1\
    --pdf $outDir/pdf/prr_v_dc_agg_eb.pdf\
    < $sd/prr_v_dc_scatter.R


  R --no-save --slave \
    --args \
    --dir lr \
    $bwOptions \
    $flood6Options \
    --labels bw\
    --aggByLabel 0\
    --plotErrorBars 0\
    --pdf $outDir/pdf/prr_v_dc_all.pdf\
    < $sd/prr_v_dc_scatter.R

  R --no-save --slave \
    --args \
    --dir lr \
    $bwOptions \
    $flood6Options \
    --labels bw\
    --aggByLabel 0\
    --xmin 0.5\
    --alpha 0.75\
    --plotErrorBars 0\
    --pdf $outDir/pdf/prr_v_dc_all_zoom.pdf\
    < $sd/prr_v_dc_scatter.R

  R --no-save --slave \
    --args \
    --dir lr \
    $bwOptions \
    $flood6Options \
    --labels bw\
    --aggByLabel 0\
    --plotErrorBars 1\
    --pdf $outDir/pdf/prr_v_dc_all_eb.pdf\
    < $sd/prr_v_dc_scatter.R

  R --no-save --slave \
    --args \
    --dir lr \
    $bwOptions \
    $flood6Options \
    --labels bw\
    --aggByLabel 0\
    --xmin 0.5\
    --alpha 0.75\
    --plotErrorBars 0\
    --removeLabel 1\
    --removeLabel 2\
    --removeLabel 3\
    --removeLabel 5\
    --pdf $outDir/pdf/prr_v_dci_bw0_scatter.pdf\
    < $sd/prr_v_dc_scatter.R
     
}

function forwarderCount(){
  R --no-save --slave \
    --args\
    $bwOptions \
    --removeNode 58\
    --removeLabel 3\
    --errorBars 0\
    --sortEach 1\
    --pdf $outDir/pdf/forwarder_count_bw_sorted.pdf\
    < $sd/forwarder_count.R

  R --no-save --slave \
    --args\
    $bwOptions \
    --removeNode 58\
    --removeLabel 3\
    --errorBars 0\
    --sortEach 0\
    --pdf $outDir/pdf/forwarder_count_bw.pdf\
    < $sd/forwarder_count.R

  R --no-save --slave \
    --args\
    $bwOptions \
    --removeNode 58\
    --removeLabel 0\
    --removeLabel 1\
    --removeLabel 3\
    --removeLabel 5\
    --errorBars 1\
    --sortLabel 2\
    --sortEach 0\
    --pdf $outDir/pdf/forwarder_count_bw_errorbars.pdf\
    < $sd/forwarder_count.R

}

function asym(){
  f=data_final/testbed/distance_stretch_db/type.flood.bw.0.sel.0.txp.0x2D.ipi.61440.thresh.-100.sm.map.nonroot.tn.4.1349803136.db

  R --no-save --slave \
  --args \
  --db $f \
  --plotHeight 2.5\
  --plotWidth 4\
  --pdf asym_hist.pdf \
  < fig_scripts/asym_hist.R
}

function all(){
  bw
  sel
  depthVTime
  floodDCHist
  xVTxp
  dciVTxp
  phy
  sim
  spatial
  forwarderCount
  prr_v_dc
#  extrapolation
}
asym
