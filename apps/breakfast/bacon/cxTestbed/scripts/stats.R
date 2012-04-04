inTicks <- FALSE

for (e in commandArgs()[(which(commandArgs() == "--args")+1):length(commandArgs())]){
  ep = strsplit(e, '=', fixed=TRUE)
  name = ep[[1]][1]
  val = ep[[1]][2]
  if (name == 'dataFile'){
    dataFile <- val
  }
  if (name == 'inTicks'){
    inTicks <- as.logical(val)
  }
}

x <- read.csv(dataFile, sep=' ', header=F, col.names=c('t', 'duration'))
if (inTicks){
  x$duration <- x$duration*(4/26e6)
}
#want: min, max, median, q5 q95, mean, stdev
durationQuantiles <- quantile(x$duration, c(0.05, 0.95))
print(paste(
  min(x$duration), 
  durationQuantiles[1],
  median(x$duration),
  durationQuantiles[2],
  max(x$duration), 
  mean(x$duration),
  sd(x$duration)
  ), quote=F)
