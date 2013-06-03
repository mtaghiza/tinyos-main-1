#!/bin/bash
./rrb.3.lq.sh static.rrb.3.lq
sleep 7200
./dynamic.rrb.3.lq.sh dynamic.rrb.3.lq
sleep 7200
./rrb.3.1min.sh dynamic.rrb.3.1min
sleep 14400
./fb.1min.sh dynamic.fb.1min
sleep 14400

cd ~/tinyos-2.x/apps/breakfast/bacon/testbed/scripts
wget http://sensorbed.hinrg.cs.jhu.edu/logs/current -O ../data/overnight.0603.log
mkdir -p ../data/overnight.0603/db
mkdir -p ../data/overnight.0603/logs
./split.sh ../data/overnight.0603.log ../data/overnight.0603/logs

for f in ../data/overnight.0603/logs/*.log
do
  ./processLog.sh $f ../data/overnight.0603/db/$(basename $f)
done
