#!/bin/bash
platform=$1
defFile=$2
outFile=$3
shift 3

className=$(basename $outFile | cut -d '.' -f 1)
typeName=$(echo $className | sed -re 's,([A-Z]),_\l\1,g' -e 's,^_,,')

mig python -target=$platform $@ -python-classname=$className $defFile $typeName -o $outFile
