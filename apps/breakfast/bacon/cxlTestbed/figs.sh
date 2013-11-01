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

echo "Segmentation DC: leaf idle"
R --no-save --slave --args $dbArgs\
  --router 0 --ppd 0 \
  --lpos ur\
  --ymin 0 --ymax 0.5 \
  --size big --pdf figs/segmentation_dc_leaf_idle.pdf\
  < R/segmentation_dc.R

echo "Segmentation DC: leaf active"
R --no-save --slave --args $dbArgs\
  --router 0 --ppd 75 \
  --lpos ur\
  --ymin 0 --ymax 0.5 \
  --size big --pdf figs/segmentation_dc_leaf_active.pdf\
  < R/segmentation_dc.R


echo "Segmentation DC: router idle"
R --no-save --slave --args $dbArgs\
  --router 1 --ppd 0 \
  --lpos ul\
  --ymin 0 --ymax 1.4 \
  --size big --pdf figs/segmentation_dc_router_idle.pdf\
  < R/segmentation_dc.R

echo "Segmentation DC: router active"
R --no-save --slave --args $dbArgs\
  --router 1 --ppd 75 \
  --lpos bl\
  --ymin 0 --ymax 1.4 \
  --size big --pdf figs/segmentation_dc_router_active.pdf\
  < R/segmentation_dc.R
exit 0
echo "validation dc" 
R --no-save --slave --args $dbArgs \
  --plotType cdf \
  --size big --pdf figs/validation_dc_cdf.pdf \
  < R/validation_dc.R 
echo "validation dc" 
R --no-save --slave --args $dbArgs \
  --plotType hist \
  --efs 0\
  --xmax 0.3\
  --bw 0.01\
  --size big --pdf figs/validation_dc_hist_efs_0.pdf \
  < R/validation_dc.R 
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
  --size big --pdf figs/validation_prr_rl_efs_0.pdf \
  < R/validation_prr.R

R --slave --no-save --args $dbArgs \
  --bl 42 --dir lr --efs 0\
  --size big --pdf figs/validation_prr_lr_efs_0.pdf \
  < R/validation_prr.R

R --slave --no-save --args $dbArgs \
  --bl 42 --dir rl --efs 1\
  --size big --pdf figs/validation_prr_rl_efs_1.pdf \
  < R/validation_prr.R

R --slave --no-save --args $dbArgs \
  --bl 42 --dir lr --efs 1\
  --size big --pdf figs/validation_prr_lr_efs_1.pdf \
  < R/validation_prr.R

echo "validation throughput v distance"
R --no-save --slave --args --size big \
  --db data/1028_cx/tb.db \
  --pdf figs/validation_throughput.pdf \
  < R/validation_throughput.R


