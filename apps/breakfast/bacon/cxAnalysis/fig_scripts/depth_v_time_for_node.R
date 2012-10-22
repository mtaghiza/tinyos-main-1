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

plotType <- 'time'
testBreaks <- c()
breakLen <- 600
lr <- c()
rl <- c()
for (i in seq(argStart, argc-1)){
  opt <- commandArgs()[i]
  val <- commandArgs()[i+1]
  if ( opt == '--db'){
    fn <- val
    bn <- strsplit(fn, '\\.')[[1]]
    bn <- bn[length(bn)-1]
    if (bn %in% rl$bn){
      print(paste("Duplicate", fn))
      next
    }
    con <- dbConnect(dbDriver("SQLite"), dbname=fn)
    
    label <- commandArgs()[i+2]
    rlTmp <- dbGetQuery(con, rlQ, nodeId)
    rlTmp$label <- label
    rlTmp$bn <- bn
    lrTmp <- dbGetQuery(con, lrQ, nodeId)
    if (length(lrTmp$ts) > 0){
      lrTmp$label <- label
    }
    if (length(rl) > 0){
      rlTmp$ts <- rlTmp$ts - min(rlTmp$ts) + max(rl$ts) + breakLen
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
    pdf(val, width=4, height=3, title=paste("Node",nodeId, "depth time series"))
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
  if (opt == '--plotType'){
    plotType <- val
  }
}
testBreaks <- testBreaks-min(rl$ts)
rl$sn = 1:length(rl$ts)

if (ymin == -1){
  ymin <- 1
}
if (ymax == -1){
  ymax <-max(c(rl$depth, lr$depth)) 
}
if (plotType == 'time'){
  ds <- 2
  print(
    ggplot(rl[rl$sn %% ds == 0,], aes(x=ts-min(ts), y=depth)) 
    + geom_point(size=0.5)
#    + geom_vline(xintercept=testBreaks, color='gray')
    + theme_bw() 
    + theme(panel.grid.major=element_blank(),panel.grid.minor=element_blank())
    + xlab("Time (s)")
    + ylab("Distance from Root")
    + scale_y_continuous(limits=c(ymin, ymax))
  )
}
if (plotType == 'hist'){
  print(
    ggplot(rl, aes(x=depth))
    + geom_histogram(aes(y=..count../sum(..count..)),
      binwidth=1.0, color='black', fill='gray')
    + xlab("Distance From root")
    + ylab("Fraction")
    + theme_bw()
    + theme(panel.grid.major=element_blank(),panel.grid.minor=element_blank())
  )
}
if ( plotFile){
  g<-dev.off()
}

