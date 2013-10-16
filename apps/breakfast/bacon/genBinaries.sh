#!/bin/bash

leafDir=$(dirname $0)/Leaf
routerDir=$(dirname $0)/Router
basestationDir=$(dirname $0)/Basestation
firmwareDir=$(dirname $0)/../tools/Life/tools/firmware

gitRev=$(git log --pretty=format:'%h' -n 1)

for d in $leafDir $routerDir $basestationDir
do
  pushd .
  cd $d
  make bacon2 || exit 1
  popd
done

cp $leafDir/build/bacon2/main.ihex $firmwareDir/leaf.ihex
cp $routerDir/build/bacon2/main.ihex $firmwareDir/router.ihex
cp $basestationDir/build/bacon2/main.ihex $firmwareDir/basestation.ihex
echo "Generated from $gitRev at $(date)" > $firmwareDir/version.txt
