#!/bin/bash

if [ $# -lt 2 -o "$(basename $0)" == "$(basename ${BASH_SOURCE})" ]
then
cat 1>&2 <<EOF
 Usage: source $0 <map> <label> [option files]
 Note: this *must* be source'd from another bash file, not ./'d or run
   directly.
   This is required for recording meta-information.
EOF
  exit 1
fi
echo "passed"
MAP=$1
label=$2
shift 2

options=$(paste -d ' ' $@)
#For Make to be happy with this, we need to have a string with both
#  the quotes and spaces escaped. 

if [ $(git diff | wc -l) -gt 0 ]
then
  echo "WARNING: uncommitted changes present!" 1>&2
fi
#grab meta-information about test environment
sha=$(git log HEAD^..HEAD --format=format:%H)
installScript=$(basename $0)

#The sed command replaces ' ' with '\ ', so each space looks like
# \ 
#The \\\" corresponds to the string literal:
# \"
settings=\\\"$(echo "$options HASH=$sha SCRIPT=$installScript LABEL=$label" | sed 's/ /\\ /g')\\\"

#Unclear to me why $settings has to be quoted, but I also don't care.
# stupid strings.
make bacon2 $options TEST_DESC="$settings" 
makeEC=$?

if [ $makeEC -ne 0 ]
then
  exit $makeEC
fi

for i in $(grep -v '#' $MAP | awk '{print $2}')
do
  make bacon2 reinstall,$i wpt,$MAP
done
