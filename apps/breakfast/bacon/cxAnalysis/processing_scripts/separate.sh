#!/bin/bash
if [ $# -lt 2 ]
then
  echo "Usage: $0 <logfile> <outputDir> [root=0]" 2>&1
  exit 1
fi

lf=$1
od=$2
rootId=0
tf=tmp.log
if [ $(file $lf | grep -c 'CRLF') -eq 1 ] 
then 
  dos2unix $lf
fi

set -x 
if [ $# -gt 2 ]
then
  rootId=$3
fi

mkdir -p $od
# for each start message for root
grep -n " $rootId START" $lf | tr ':_' ' ' | cut -d ' ' -f 1 | while read s
do
  # cut from start -> end of full log and put in tmp
  tail --lines=+$s $lf > $tf
  # read label from first line of tmp file
  settingsLine=$(head -1 $tf)
  label=$(echo "$settingsLine" | tr '/' '.'| tr '_' ' ' | cut -d ' ' -f 7 )
  id=$(head -1 $tf | tr '_' ' '| cut -d ' ' -f 5)
  of=$od/$label.$id.log 
  echo "Separating to $of"
  #is there another START in here?
  if [ $(grep -c " $rootId START" $tf) -gt 1 ]
  then 
    #find it
    e=$(tail --lines=+2 $tf | grep -n " $rootId START" | head -1 | tr ':' ' ' | cut -d ' ' -f 1)
    #cut to it and put in final
    head --lines=$e $tf > $of
  else
    #save as output file
    mv $tf $of
  fi
#  #cut end: if stuff happened after the root was reprogrammed, we
#  # don't want to hear about it.
#  lastRoot=$(awk '($2 == 0){print NR}' < $of | tail -1)
#  head --lines=$lastRoot $of > $tf
#  mv $tf $of
done

touch $tf 
rm $tf
