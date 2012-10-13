library(RSQLite)
library(ggplot2)
fn <- ''
plotFile <- F
argc <- length(commandArgs())
argStart <- 1 + which (commandArgs() == '--args')
nodeId <- -1
ymin <- -1
ymax <- -1
rlQ <- "SELECT ts, depth FROM rx_all WHERE src=0 AND dest = ? ORDER by ts;"
lrQ <- "SELECT ts, depth FROM rx_all WHERE dest=0 AND src = ? ORDER by ts;"

testBreaks <- c()
lr <- c()
rl <- c()
for (i in seq(argStart, argc-1)){
  opt <- commandArgs()[i]
  val <- commandArgs()[i+1]
  if ( opt == '--db'){
    fn <- val
    con <- dbConnect(dbDriver("SQLite"), dbname=fn)
    
    label <- commandArgs()[i+2]
    rlTmp <- dbGetQuery(con, rlQ, nodeId)
    rlTmp$label <- label
    lrTmp <- dbGetQuery(con, lrQ, nodeId)
    if (length(lrTmp$ts) > 0){
      lrTmp$label <- label
    }
    if (length(rl) > 0){
      rlTmp$ts <- rlTmp$ts - min(rlTmp$ts) + max(rl$ts)
    }
    testBreaks <- rbind(testBreaks, min(rlTmp$ts))
    lr <- rbind(lr, lrTmp)
    rl <- rbind(rl, rlTmp)
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
  if (opt == '--ymin'){
    ymin <- as.numeric(val)
  }
  if (opt == '--ymax'){
    ymax <- as.numeric(val)
  }
}
testBreaks <- testBreaks-min(rl$ts)

if (ymin == -1){
  ymin <- 1
}
if (ymax == -1){
  ymax <-max(c(rl$depth, lr$depth)) 
}
print(
  ggplot(rl, aes(x=ts-min(ts), y=depth)) 
  + geom_point(size=0.5)
  + geom_vline(xintercept=testBreaks, color='gray')
  + theme_bw()
  + xlab("Time (s)")
  + ylab("Distance from Root")
  + scale_y_continuous(limits=c(ymin, ymax))
  + ggtitle(paste("Node", nodeId, " Distance v. Time"))
)
if ( plotFile){
  g<-dev.off()
}

