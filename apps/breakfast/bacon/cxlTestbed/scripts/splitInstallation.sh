#!/bin/bash

if [ $# -lt 2 ]
then
  exit 1
fi
f=$1
d=$2

# get distinct installTS's
# for each pair of boundaries, use awk to spit out all the lines with
#   ts between range
tsList=($(grep SETUP $f | tr '_' ' ' | awk '{
  for ( i = 4; i < NF; i+=2){
    if ($i == "installTS"){
      print $(i+1)
    }
  }
}' | uniq))

now=$(date +%s)
limits=( 0 ${tsList[@]} $now )

for i in $(seq 0 $(( ${#limits[@]} - 2)))
do
  lowerLimit=${limits[$i]}
  upperLimit=${limits[$(($i + 1 ))]}
  echo "$lowerLimit $upperLimit"
  awk -v lowerLimit=$lowerLimit -v upperLimit=$upperLimit '
  ($1 >= lowerLimit && $1 <= upperLimit){
    print $0
  }
  ' $f > $d/$lowerLimit
done
