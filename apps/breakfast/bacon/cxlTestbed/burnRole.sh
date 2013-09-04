#!/bin/bash
if [ $# -lt 2 ]
then 
  exit 1
fi

MAP=$(pwd)/$1
role=$2
shift 2

pushd .
cd ../$role
make bacon2 $@

if [ $? -eq 0 ]
then
  for i in $(grep -v '#' $MAP | grep $role | awk '{print $2}')
  do
    make bacon2 reinstall,$i wpt,$MAP
  done
  popd
else
  echo "BUILD FAILED"
  popd
  exit 1
fi
