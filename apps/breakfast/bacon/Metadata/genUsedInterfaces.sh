#!/bin/bash
echo "//Begin Auto-generated used interfaces (see genUsedInterfaces.sh)"

echo "//Receive"
grep 'AM' ctrl_messages.h | grep 'CMD' | awk '{print $1}'| while read amId
do
  ca=$(echo $amId | tr '[:upper:]' '[:lower:]')
  ca=$(echo $ca | rev | cut -d '_' -f 1 --complement | rev | cut -d '_' -f 1 --complement)
  ca="$(echo $ca | sed -re 's/(^|_)([a-z])/\u\2/g')Receive"
  echo "uses interface Receive as ${ca};";
done

echo "//Send"
grep 'AM' ctrl_messages.h | grep 'RESPONSE' | awk '{print $1}'| while read amId
do
  ca=$(echo $amId | tr '[:upper:]' '[:lower:]')
  ca=$(echo $ca | rev | cut -d '_' -f 1 --complement | rev | cut -d '_' -f 1 --complement)
  ca="$(echo $ca | sed -re 's/(^|_)([a-z])/\u\2/g')Send"
  echo "uses interface AMSend as $ca;"
done
echo "//End Auto-generated used interfaces"

