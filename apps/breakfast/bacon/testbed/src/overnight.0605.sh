#!/bin/bash

./fb.1min.sh fb.1min
sleep 14400
./idle.1min.sh idle.1min
sleep 14400

cd ~/tinyos-2.x/apps/breakfast/bacon/testbed/scripts
wget http://sensorbed.hinrg.cs.jhu.edu/logs/current -O ../data/overnight.0605.log
mkdir -p ../data/overnight.0605/db
mkdir -p ../data/overnight.0605/logs
./split.sh ../data/overnight.0605.log ../data/overnight.0605/logs

for f in ../data/overnight.0605/logs/*.log
do
  ./processLog.sh $f ../data/overnight.0605/db/$(basename $f)
done
