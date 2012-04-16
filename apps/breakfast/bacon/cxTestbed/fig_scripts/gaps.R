args <- c()

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
}

x <- read.csv(dataFile, sep=',', header=T)

#pdf('debug/gaps.pdf', title="schedule gaps")
png(paste(outPrefix, 'gaps','png', sep='.'))
#, title="schedule gaps")
plot(-10,-10, 
  xlim=c(0, max(x$ts)), 
  ylim=c(0, max(x$mc)+1),
  xlab="Time (s)",
  ylab="Schedules missed")
depths <- sort(unique(x$depth))
plotCols <- rainbow(length(depths))
for (i in seq_along(depths)){
  d <- depths[i]
  ad <- x[x$depth==d,]
  points(ad$ts, ad$mc+((i-1)/5), col=plotCols[i], pch=20)
}
legend("topright", pch=20, col=plotCols, legend=depths, title="depth")
title("Gaps in schedule receptions")

garbage <- dev.off()
