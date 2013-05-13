#!/bin/bash
od=options
sd=$(dirname $0)

if [ $# -eq 0 ]
then
  ./$sd/blink.sh 
fi


./$sd/install.sh maps/map.nonroot $od/slave.options $od/all.options $od/static.options $od/broadcast_fast.options $od/scheduled.options
echo "Hit enter when slaves are confirmed booted"
read line

./$sd/install.sh maps/map.root $od/root.options $od/all.options $od/static.options $od/rx.options
