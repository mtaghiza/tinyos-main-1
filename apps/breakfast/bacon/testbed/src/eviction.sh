#!/bin/bash
od=options
sd=$(dirname $0)

label=$1
shift 1
if [ $# -eq 0 ]
then
  ./$sd/blink.sh 
fi

source ./$sd/install.sh maps/map.root $label $od/root.options $od/all.options $od/dynamic.options $od/rx.options $od/evict3.options
source ./$sd/install.sh maps/map.odd $label $od/slave.options $od/all.options $od/dynamic.options $od/broadcast_fast.options $od/evict3.options
source ./$sd/install.sh maps/map.even $label $od/slave.options $od/all.options $od/dynamic.options $od/broadcast_slow.options $od/evict3.options

