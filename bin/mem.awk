#Distinguish generic from static elements of the program
#
#Pipe romsize.pl's output through this:
#  tail --lines=+2 | tr -s '\t' | sed 's/\([^\w]\)__/\1\t/g'
# and then to this awk script. The sed expression translates non-terminal
#   __'s to tabs.
BEGIN{
  OFS="\t"
  FS="\t"
  print "G/S", "ROM", "RAM"
}
($4 ~ /[0-9]+/){
  print "G", $1, $2, $3, $5, $6
}
($4 !~ /[0-9]+/){
  print "S", $0
}

