#!/bin/bash

if [ $# -lt 3 ]
then

cat <<EOF 1>&2
Usage: $0 <platform> <def file> <output file> [mig options]
 - This script runs $(which mig) using definitions in "def file" to
   produce "output file" (python format), following standard
   conventions.
 - The class name will be derived from the python file name (e.g.
   SomeMessage.py -> SomeMessage class)
 - The nesC type will be the lower-cased/underscore-separated version
   of the CamelCase python class name (e.g. SomeMessage ->
   some_message). 
 - As a reminder, mig will match up the nesC type identifier
   some_message with the value defined by AM_SOME_MESSAGE
 Example def file contents:

 typedef nx_struct some_message {
   nx_uint8_t field;
 } some_message_t;
 enum {
   AM_SOME_MESSAGE=0xdc,
 };

 To generate the python MIG class for this:

 $0 telosb outputDirectory/SomeMessage.py 
 
EOF
exit 1
fi

platform=$1
defFile=$2
outFile=$3
shift 3

className=$(basename $outFile | cut -d '.' -f 1)
typeName=$(echo $className | sed -re 's,([A-Z]),_\l\1,g' -e 's,^_,,')

mig python -target=$platform $@ -python-classname=$className $defFile $typeName -o $outFile
