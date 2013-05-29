#!/bin/bash
pushd .
cd ~/tinyos-2.x/apps/Blink
./burn map.all
popd
sleep 60
