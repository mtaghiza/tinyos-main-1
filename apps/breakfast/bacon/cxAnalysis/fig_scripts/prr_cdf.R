library(RSQLite)
selectQ <- "SELECT 
  a.src,
  a.dest,
  ? as lbl,
  a.prr as prr_lr
FROM prr_clean a
WHERE a.dest=0"

fn <- ''
plotFile <- F
argc <- length(commandArgs())
argStart <- 1 + which (commandArgs() == '--args')
x <- c()
xmin=0
xmax=1.0
for (i in seq(argStart, argc-1)){
  opt <- commandArgs()[i]
  val <- commandArgs()[i+1]
  if ( opt == '-f'){
    fn <- val
    lbl <- commandArgs()[i+2]
    con <- dbConnect(dbDriver("SQLite"), dbname=fn)
    x <- rbind(x, dbGetQuery(con, selectQ, lbl))
  }
  if ( opt == '--pdf' ){
    plotFile=T
    pdf(val, width=9, height=6, title="PRR Comparison CDF")
  }
  if ( opt == '--png' ){
    plotFile=T
    png(val, width=9, height=6, units="in", res=200)
  }
  if (opt == '--xmin'){
    xmin <- as.numeric(val)
  }
  if (opt == '--xmax'){
    xmax <- as.numeric(val)
  }
}

#CDF plot
yl <- c(0,1.0)
xl <- c(xmin, xmax)
firstPlot <- T
lblCols <- rainbow(length(unique(x$lbl)))
lblVals <- sort(unique(x$lbl))
medians<- c()
means<- c()
for (index in 1:length(lblVals)){
  lbl <- lblVals[index]
  lblCol <- lblCols[index]

  vals <- x[x$lbl==lbl,]
  probs <- (1:dim(vals)[1])/dim(vals)[1]
  if (firstPlot){
    firstPlot <- F
    plot(x=c(0,sort(vals$prr_lr)), y=c(0, probs), ylab='Fraction', xlab='PRR',
      xlim=xl, ylim=yl, type='l', col=lblCol)
  }else{
    par(new=T)
    plot(x=c(0,sort(vals$prr_lr)), y=c(0,probs), ylab='', xlab='', xaxt='n', yaxt='n',
      xlim=xl, ylim=yl, type='l', col=lblCol)
  }
  medians <- c(medians, median(vals$prr_lr))
  means <- c(means, mean(vals$prr_lr))
}
legend('topleft', legend=paste('lbl:', lblVals, 'Med:', round(medians,
4), 'Mean:', round(means, 4)), 
  text.col=lblCols)
title("CDF of PRR")

if ( plotFile){
  g<-dev.off()
}

