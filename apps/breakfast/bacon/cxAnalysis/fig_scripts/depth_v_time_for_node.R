fn <- ''
plotFile <- F
argc <- length(commandArgs())
argStart <- 1 + which (commandArgs() == '--args')
nodeId <- -1
for (i in seq(argStart, argc-1)){
  opt <- commandArgs()[i]
  val <- commandArgs()[i+1]
  if ( opt == '-f'){
    fn <- val
  }
  if ( opt == '-n'){
    nodeId <- as.integer(val)
  }
  if ( opt == '--pdf' ){
    plotFile=T
    pdf(val, width=9, height=6, title=paste("Node",nodeId, "depth time series"))
  }
  if ( opt == '--png' ){
    plotFile=T
    png(val, width=9, height=6, units="in", res=200)
  }
}

rlQ <- "SELECT ts, depth FROM rx_all WHERE src=0 AND dest = ? ORDER by ts;"
lrQ <- "SELECT ts, depth FROM rx_all WHERE dest=0 AND src = ? ORDER by ts;"
library(RSQLite)
con <- dbConnect(dbDriver("SQLite"), dbname=fn)


rl <- dbGetQuery(con, rlQ, nodeId)

lr <- dbGetQuery(con, lrQ, nodeId)


plot(x=rl$ts-min(rl$ts), y=rl$depth, type='o', ylab='Depth',
  xlab='Time(s)',
  ylim=c(1, max(c(rl$depth, lr$depth))), 
  col='red')

points(x=lr$ts-min(rl$ts), y=lr$depth, col='blue', type='o', pch=16, lty=2)
title(paste('Node', nodeId,'Distance v. Time'))
legend('topleft', c('Root->Leaf', 'Leaf->Root'),
  text.col=c('red','blue'),
  col=c('red', 'blue'),
  lty=c(1,2),
  pch=c(1, 16))
if ( plotFile){
  g<-dev.off()
}

