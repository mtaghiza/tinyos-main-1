#!/bin/bash

#input: src, dest, failure rate p
# number of trials (selections of nodes)

if [ $# -lt 4 ]
then
  echo "Usage: $0 db src dest failureRate" 1>&2
  exit 1
fi

db=$1
src=$2
dest=$3
fr=$4
numTrials=10
txPerTrial=20 
function sendCommandGeneric(){
  delay=$1
  id=$2
  shift 2
  s="$@"
  for (( i=0; i<${#s}; i++ ))
  do
    echo "${s:$i:1}" | nc localhost $((17000 + $id))
    sleep $delay
  done
}

function sendCommandNoDelay(){
  sendCommandGeneric 0 $@
}

function resetNetwork(){
  for node in $(seq 60)
  do
    sendCommandNoDelay $node q
  done
}

function tx(){
  #0.4 delay is to let the tx finish: 10 hops, ~31 ms per hop=0.3 S
  sendCommandGeneric 0.4 $1 t
}

for setup in "cx" "sp"
do 
  setupStart=$(date +%s)
  echo "$setupStart SETUP_START $setup $src $dest $fr"
  resetNetwork
  for i in $(seq $numTrials)
  do
    #on each TX, randomly set up the nodes to sleep or rx/forward.
    #this simulates a single connection.

    trialStart=$(date +%s) 
    python randomize.py $db $setup $src $dest $fr | while read nodeCommand
    do
      echo "$trialStart TRIAL $setupStart $nodeCommand"
      sendCommandNoDelay $nodeCommand
    done
    sleep 0.1
    for k in $(seq $txPerTrial)
    do
      tx $src
    done
    sleep 1.5
  done
done
