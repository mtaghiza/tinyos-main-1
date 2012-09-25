library(RSQLite)
selectQ <- "SELECT
  ? as label,
  node,
  dc
FROM duty_cycle
WHERE dc is not NULL"

fn <- ''
plotFile <- F
argc <- length(commandArgs())
argStart <- 1 + which (commandArgs() == '--args')
x <- c()
nx <- c()

#results are normalized to the file provided with -nf option
for (i in seq(argStart, argc-1)){
  opt <- commandArgs()[i]
  val <- commandArgs()[i+1]
  if ( opt == '-nf'){
    fn <- val
    lbl <- commandArgs()[i+2]
    con <- dbConnect(dbDriver("SQLite"), dbname=fn)
    nx <- dbGetQuery(con, selectQ, lbl)
  }
  if ( opt == '-f'){
    fn <- val
    lbl <- commandArgs()[i+2]
    con <- dbConnect(dbDriver("SQLite"), dbname=fn)
    x <- rbind(x, dbGetQuery(con, selectQ, lbl))
  }
  if ( opt == '--pdf' ){
    plotFile=T
    pdf(val, width=9, height=6, title="Duty Cycle CDF")
  }
  if ( opt == '--png' ){
    plotFile=T
    png(val, width=9, height=6, units="in", res=200)
  }
}
x <- merge(nx, x, by='node', suffixes=c('.ref', '.var'))
x$normalized <- x$dc.var/x$dc.ref

#CDF plot
yl <- c(0, 1.0)
xl <- c(0, 2.0)
firstPlot <- T
rCols <- rainbow(length(unique(x$label.var)))
labelVals <- sort(unique(x$label.var))
medians<-c()
means<-c()
for (index in 1:length(labelVals)){
  label <- labelVals[index]
  rCol <- rCols[index]

  vals <- x[x$label.var == label,]
  probs <- (1:dim(vals)[1])/dim(vals)[1]
  if (firstPlot){
    firstPlot <- F
    plot(x=c(0,sort(vals$normalized), 10), y=c(0, probs,1), ylab='Fraction',
      xlab='Duty Cycle Improvement (normalized to flood)',
      xlim=xl, ylim=yl, type='l', col=rCol)
  }else{
    par(new=T)
    plot(x=c(0,sort(vals$normalized), 10), y=c(0,probs, 1), ylab='', xlab='', xaxt='n', yaxt='n',
      xlim=xl, ylim=yl, type='l', col=rCol)
  }
    
  medians <- c(medians, median(vals$normalized))
  means <- c(means, mean(vals$normalized))
}
legend('bottomright', legend=paste('Label:', labelVals, 'Med Improvement:',
  round(medians, 2), 'Mean:', round(means, 2)), 
  text.col=rCols)
title("Duty Cycle Improvement: < 1.0 is good, > 1.0 is bad.")
lines(c(1.0, 1.0), c(-1, 2), lty=2)

if ( plotFile){
  g<-dev.off()
}
