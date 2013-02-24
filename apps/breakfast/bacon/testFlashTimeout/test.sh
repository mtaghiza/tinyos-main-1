#!/bin/bash

for timeout in 256 512 1024 2048 4096 8192 16384 32768 65536
do
  for i in $(seq 5)
  do
    echo "$(date) $timeout" >> install.log
    make bacon2 STM25P_SHUTDOWN_TIMEOUT=${timeout}UL install,1 2>&1 >> install.log
    python dump.py serial@/dev/ttyUSB0:115200 1 $timeout | tee -a tests/${timeout}.$i.txt
  done
done
