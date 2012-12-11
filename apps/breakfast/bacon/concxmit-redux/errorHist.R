
plotHist<- function(x, f, cycleLen){
  pdf(paste(f, cycleLen, 'pdf', sep='.'))
  hist((x$p%%cycleLen)+0.5, breaks=-1:cycleLen)
  g <- dev.off()
}

allPlots <- function(f){
  x <- read.csv(f, sep=' ', col.names=c('g', 'pos'))
  plotHist(x, f, max(x$p))
  plotHist(x, f, 4)
  plotHist(x, f, 8)
}

allPlots('sameFB.ep')
allPlots('randomFB.ep')
