#!/bin/bash
if [ $# -lt 1 ]
then
  echo "usage: $0 <.ia file>" 1>&2
  exit 1
fi
awk -F '=' '/P_/{print $2}' $1
