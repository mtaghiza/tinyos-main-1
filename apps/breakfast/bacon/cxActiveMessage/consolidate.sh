#!/bin/bash

snOffset=0
snIncrement=1000
while [ $# -gt 0 ]
do
  logFile=$1
  echo "Consolidating $logFile (SN offset: $snOffset)" 1>&2
  cat $logFile | awk --assign snOffset=$snOffset '($3 == "RX" && NF == 17){print $1, $2, $3, $4, $5, $6, $7, $8, ($9 + snOffset), $10, $11, $12, $13, $14, $15, $16, $17}' 
  cat $logFile | awk --assign snOffset=$snOffset '($3 == "TX" && NF == 21){print $1, $2, $3, $4, $5, $6, $7, $8, ($9 + snOffset), $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21}' 
  cat $logFile | awk --assign snOffset=$snOffset '($3 == "UBF" && NF == 19){print $1, $2, $3, $4, $5, $6, $7, $8, ($9 + snOffset), $10, $11, $12, $13, $14, $15, $16, $17, $18, $19}' 
  cat $logFile | grep '!\[' 
  snOffset=$(($snOffset + $snIncrement))
  shift 1
done
