#!/bin/bash

set -x

routerPower=0xC3
leafPower=0x2D
enablePrintf=0
for map in map.p0 map.p1 map.p2 map.p3
do
  snc=$(grep SNC $map | cut -d ' ' -f 2)
  ./burnRole.sh $map Router\
    MAX_POWER=$routerPower\
    GLOBAL_CHANNEL=0\
    SUBNETWORK_CHANNEL=$snc\
    ROUTER_CHANNEL=64\
    ENABLE_AUTOPUSH=1\
    ENABLE_PRINTF=$enablePrintf || exit 1
  ./burnRole.sh $map Leaf -f Makefile.dummycxl \
    MAX_POWER=$leafPower\
    GLOBAL_CHANNEL=0\
    SUBNETWORK_CHANNEL=$snc\
    ROUTER_CHANNEL=64\
    ENABLE_AUTOPUSH=1\
    ENABLE_PRINTF=$enablePrintf || exit 1
done  
