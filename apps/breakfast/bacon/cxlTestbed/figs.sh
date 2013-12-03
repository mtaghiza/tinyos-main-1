#!/bin/bash

if [ $# -lt 1 ]
then
  exit 1
fi

dbFiles=($@)

dbArgs=""
for dbf in ${dbFiles[@]}
do
  dbArgs="$dbArgs --db $dbf "
done

function segmentationCheck(){
  R --no-save --slave --args $dbArgs\
    --plotPatchSize 0 \
    --router 1 --ppd 75 \
    --lpos ul\
    --plotData relative\
    --plotType histogram\
    --ymin 0.0 --ymax 2.0 \
    --xmin 0 --xmax 2.5\
    --size big --pdf figs/segmentation_dc_router_active_rel_hist.pdf \
    < R/segmentation_dc.R

  R --no-save --slave --args $dbArgs\
    --plotPatchSize 0 \
    --router 0 --ppd 75 \
    --lpos ul\
    --plotData relative\
    --plotType histogram\
    --ymin 0.0 --ymax 2.0 \
    --xmin 0 --xmax 2.5\
    --size big --pdf figs/segmentation_dc_leaf_active_rel_hist.pdf \
    < R/segmentation_dc.R
  exit 0
  R --no-save --slave --args $dbArgs\
    --plotPatchSize 0 \
    --router 0 --ppd 75 \
    --lpos ul\
    --plotData flat\
    --ymin 0.0 --ymax 2.0 \
    --xmin 0 --xmax 2.5\
    --size big --pdf figs/segmentation_dc_leaf_active_flat.pdf \
    < R/segmentation_dc.R
  
  R --no-save --slave --args $dbArgs\
    --plotPatchSize 0 \
    --router 0 --ppd 75 \
    --lpos ul\
    --plotData mt\
    --ymin 0.0 --ymax 2.0 \
    --xmin 0 --xmax 2.5\
    --size big --pdf figs/segmentation_dc_leaf_active_mt.pdf \
    < R/segmentation_dc.R

  R --no-save --slave --args $dbArgs\
    --plotPatchSize 0 \
    --router 0 --ppd 75 \
    --lpos ul\
    --plotData relative\
    --ymin 0.0 --ymax 2.0 \
    --xmin 0 --xmax 2.5\
    --size big --pdf figs/segmentation_dc_leaf_active_relative.pdf \
    < R/segmentation_dc.R
}

function segmentationPres(){
  echo "Segmentation DC: leaf idle"
  R --no-save --slave --args $dbArgs\
    --plotPatchSize 0 \
    --router 0 --ppd 0 \
    --lpos ul\
    --ymin 0.0 --ymax 2.0 \
    --xmin 0 --xmax 2.5\
    --size big --pdf figs/segmentation_dc_leaf_idle_pres.pdf \
    < R/segmentation_dc.R
  
  echo "Segmentation DC: leaf active"
  R --no-save --slave --args $dbArgs\
    --plotPatchSize 0 \
    --router 0 --ppd 75 \
    --lpos ur\
    --ymin 0.0 --ymax 2.0 \
    --xmin 0 --xmax 2.5\
    --size big --pdf figs/segmentation_dc_leaf_active_pres.pdf \
    < R/segmentation_dc.R
  
  echo "Segmentation DC: router idle"
  R --no-save --slave --args $dbArgs\
    --plotPatchSize 0 \
    --router 1 --ppd 0 \
    --lpos bl\
    --ymin 0.0 --ymax 2.0 \
    --xmin 0 --xmax 2.5\
    --size big --pdf figs/segmentation_dc_router_idle_pres.pdf \
    < R/segmentation_dc.R
  
  echo "Segmentation DC: router active"
  R --no-save --slave --args $dbArgs\
    --plotPatchSize 0 \
    --router 1 --ppd 75 \
    --lpos bl\
    --ymin 0.0 --ymax 2.0 \
    --xmin 0 --xmax 2.5\
    --size big --pdf figs/segmentation_dc_router_active_pres.pdf \
    < R/segmentation_dc.R
}

segmentationCheck
exit 0

echo "segmentation PRR"
R --slave --no-save --args $dbArgs \
  --bl 42 --dir rl --efs 0\
  --xmin -0.15 --xmax 0.15\
  --size big --pdf figs/segmentation_prr.pdf \
  < R/segmentation_prr.R

echo "Segmentation DC: leaf idle"
R --no-save --slave --args $dbArgs\
  --router 0 --ppd 0 \
  --lpos ul\
  --ymin 0.3 --ymax 2.0 \
  --xmin 0 --xmax 2.5\
  --size big --pdf figs/segmentation_dc_leaf_idle.pdf\
  < R/segmentation_dc.R

echo "Segmentation DC: leaf active"
R --no-save --slave --args $dbArgs\
  --router 0 --ppd 75 \
  --lpos ur\
  --ymin 0.3 --ymax 2.0 \
  --xmin 0 --xmax 2.5\
  --size big --pdf figs/segmentation_dc_leaf_active.pdf\
  < R/segmentation_dc.R

echo "Segmentation DC: router idle"
R --no-save --slave --args $dbArgs\
  --router 1 --ppd 0 \
  --lpos bl\
  --ymin 0.3 --ymax 2.0 \
  --xmin 0 --xmax 2.5\
  --size big --pdf figs/segmentation_dc_router_idle.pdf\
  < R/segmentation_dc.R

echo "Segmentation DC: router active"
R --no-save --slave --args $dbArgs\
  --router 1 --ppd 75 \
  --lpos bl\
  --ymin 0.3 --ymax 2.0 \
  --xmin 0 --xmax 2.5\
  --size big --pdf figs/segmentation_dc_router_active.pdf\
  < R/segmentation_dc.R

echo "validation dc cdf" 
R --no-save --slave --args $dbArgs \
  --plotType cdf \
  --size big --pdf figs/validation_dc_cdf.pdf \
  < R/validation_dc.R 

echo "validation dc hist: efs 0" 
R --no-save --slave --args $dbArgs \
  --plotType hist \
  --efs 0\
  --xmax 0.3\
  --bw 0.01\
  --size big --pdf figs/validation_dc_hist_efs_0.pdf \
  < R/validation_dc.R 

echo "validation dc hist: efs 1" 
R --no-save --slave --args $dbArgs \
  --plotType hist \
  --efs 1\
  --xmax 0.3\
  --bw 0.01\
  --size big --pdf figs/validation_dc_hist_efs_1.pdf \
  < R/validation_dc.R 

echo "validation PRR"
R --slave --no-save --args $dbArgs \
  --bl 42 --dir rl --efs 0\
  --xmin 0.80 \
  --size big --pdf figs/validation_prr_rl_efs_0.pdf \
  < R/validation_prr.R

R --slave --no-save --args $dbArgs \
  --bl 42 --dir lr --efs 0\
  --xmin 0.80 \
  --size big --pdf figs/validation_prr_lr_efs_0.pdf \
  < R/validation_prr.R

R --slave --no-save --args $dbArgs \
  --bl 42 --dir rl --efs 1\
  --xmin 0.80 \
  --size big --pdf figs/validation_prr_rl_efs_1.pdf \
  < R/validation_prr.R

R --slave --no-save --args $dbArgs \
  --bl 42 --dir lr --efs 1\
  --xmin 0.80 \
  --size big --pdf figs/validation_prr_lr_efs_1.pdf \
  < R/validation_prr.R

echo "validation throughput v distance"
R --no-save --slave --args --size big \
  --db data/1028_cx/tb.db \
  --pdf figs/validation_throughput.pdf \
  < R/validation_throughput.R

echo "Slot overhead: active"
R --slave --no-save --args $dbArgs\
  --ppd 75 \
  --size big --pdf figs/slot_overhead_active.pdf \
  < R/overhead_slots.R
echo "Slot overhead: idle"
R --slave --no-save --args $dbArgs\
  --ppd 0 \
  --size big --pdf figs/slot_overhead_idle.pdf \
  < R/overhead_slots.R

