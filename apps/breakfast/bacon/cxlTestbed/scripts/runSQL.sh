#!/bin/bash
db=$1

sqldir=sql
cat $sqldir/scripts.txt | while read f
do
  echo "RUNNING: $f"
  sqlite3 $db < $sqldir/$f
done
