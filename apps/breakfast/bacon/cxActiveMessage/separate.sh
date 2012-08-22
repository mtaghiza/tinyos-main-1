#!/bin/bash
if [ $# -lt 2 ]
then
  echo "Usage: $0 <logfile> <outputDir>" 2>&1
  exit 1
fi

lf=$1
od=$2
tf=tmp.log
if [ $(file $lf | grep -c 'CRLF') -eq 1 ] 
then 
  dos2unix $lf
fi

# for each start message for root
grep -n ' 7 START' $lf | tr ':' ' ' | cut -d ' ' -f 1 | while read s
do
  # cut from start -> end of full log and put in tmp
  tail --lines=+$s $lf > $tf
  # read label from first line of tmp file
  label=$(head -1 $tf | cut -d ' ' -f 4)
  of=$od/$label.log 
  echo "Separating to $of"
  #is there another START in here?
  if [ $(grep -c ' 7 START' $tf) -gt 1 ]
  then 
    #find it
    e=$(tail --lines=+2 $tf | grep -n ' 7 START' | head -1 | tr ':' ' ' | cut -d ' ' -f 1)
    #cut to it and put in final
    head --lines=$e $tf > $of
  else
    #save as output file
    mv $tf $of
  fi
done

touch $tf 
rm $tf
