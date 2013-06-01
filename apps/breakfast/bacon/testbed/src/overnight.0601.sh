#!/bin/bash
./rrb.0.sh static.rrb.0
sleep 7200
./rrb.1.sh static.rrb.1
sleep 7200
./rrb.2.sh static.rrb.2
sleep 7200
./rrb.3.sh static.rrb.3
sleep 7200
./dynamic.rrb.2.sh dynamic.rrb.2
sleep 7200
./all.tx.sh static.fb
sleep 7200
./dynamic.tx.sh dynamic.fb
sleep 7200
cd ~/tinyos-2.x/apps/breakfast/bacon/testbed/data
wget http://sensorbed.hinrg.cs.jhu.edu/logs/current -O overnight.0601.log
cd ~/tinyos-2.x/apps/breakfast/bacon/testbed/scripts
mkdir -p ../data/overnight.0601/db
mkdir -p ../data/overnight.0601/logs
./split.sh ../data/overnight.0601.log ../data/overnight.0601/logs
for f in ../data/overnight.0601/logs
do
  ./processLog.sh $f ../data/overnight.0601/db/$(basename $f)
done
