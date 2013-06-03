#!/bin/bash
od=options
sd=$(dirname $0)

label=$1
shift 1
if [ $# -eq 0 ]
then
  ./$sd/blink.sh 
fi

source ./$sd/install.sh maps/map.root $label $od/root.options $od/rrb.options $od/dynamic.options $od/rx.options $od/bw_3.options $od/network.options $od/linkqueue.options

source ./$sd/install.sh maps/map.nonroot $label $od/slave.options $od/rrb.options $od/dynamic.options $od/unicast_fast.options $od/bw_3.options $od/network.options $od/linkqueue.options

