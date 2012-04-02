args <- c()

plotPdf <- F
outPrefix <- ""
for (e in commandArgs()[(which(commandArgs() == "--args")+1):length(commandArgs())]){
  ep = strsplit(e,"=",fixed=TRUE)
  name=ep[[1]][1]
  val=ep[[1]][2]

  if (name == 'dataFile'){
    dataFile <- val
  }
  if (name == 'outPrefix'){
    outPrefix <- val
  }
  if (name == 'plotPdf'){
    plotPdf <- as.logical(val)
  }
}

source('fig_scripts/cdf.R')
x <- read.csv(dataFile, sep=',', header=T)

ds <- x$activeFrac
xl <- "f_active [0,1.0]"
yl <- "P [0, 1.0]"
t <- "Fraction of time in active radio modes"
plotCdf(ds, xl, yl, t, plotPdf, paste(outPrefix, 'dc_active','pdf', sep='.'))

ds <- x$avgCurrent*1000
xl <- "Average current (mA)"
yl <- "P [0, 1.0]"
t <- "Distribution of current consumption"
plotCdf(ds, xl, yl, t, plotPdf, paste(outPrefix, 'dc_cur','pdf', sep='.'))

