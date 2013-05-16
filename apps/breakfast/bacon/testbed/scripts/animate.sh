#!/bin/bash
if [ $# -lt 4 ]
then 
  echo "Usage: $0 dbFile outFile src sn [maxSteps=8]" 1>&2
  exit 1
fi
db=$1
outFile=$2
src=$3
sn=$4
steps=8
shift 4

if [ $# -gt 0 ]
then
  steps=$1
fi

sd=$(dirname $0)

tfDir=tmp
mkdir -p $tfDir
tf=$(tempfile -d $tfDir)

for i in $(seq 1 $steps)
do
  echo "Plotting step $i"
  f=$tf.$i.jpg
  python $sd/TestbedMap.py $db --trace \
    --src $src --sn $sn --step $i \
    --outFile  $f
  #add the step number
  mogrify -fill black -gravity SouthEast -draw "text 5,5 \"src: $src sn: $sn step: $i\"" $f
  last=$f
done
echo "combining to $outFile"
convert -delay 50 -loop 0 $tf.*.jpg $last $last $outFile
rm $tf.*.jpg
rm $tf
