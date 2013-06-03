#!/bin/bash
od=options
sd=$(dirname $0)

label=$1
shift 1
if [ $# -eq 0 ]
then
  ./$sd/blink.sh 
fi

source ./$sd/install.sh maps/map.root $label $od/root.options $od/all.options $od/static.options $od/rx.options $od/radiostats.options $od/network.options

source ./$sd/install.sh maps/map.nonroot $label $od/slave.options $od/all.options $od/static.options $od/rx.options $od/radiostats.options $od/network.options
