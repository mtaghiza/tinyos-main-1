plotFile <- F
argc <- length(commandArgs())
argStart <- 1 + which (commandArgs() == '--args')
x <- c()
library(plyr)
library(ggplot2)
library(RSQLite)

plotType <- 'ber'
sr <- 125
selectQ <- 'SELECT * from ber_summary'
checkQ <- 'SELECT count(*) from ber'
pw <- 8
ph <- 4
for (i in seq(argStart, argc-1)){
  opt <- commandArgs()[i]
  val <- commandArgs()[i+1]
  if (opt == '--aspect'){
    if (val == 'square'){
      pw <- 4
      ph <- 3
    }
  }
  if ( opt == '--db'){
    fn <- val
    con <- dbConnect(dbDriver("SQLite"), dbname=fn)
    sc <- as.numeric(commandArgs()[i+2])
    symbolRate <- as.numeric(commandArgs()[i+3])
    fecOn <- as.numeric(commandArgs()[i+4])
    captureMargin <- as.numeric(commandArgs()[i+5])

    cnt <- dbGetQuery(con, checkQ)
    if (cnt[1] >0){
      tmp <- dbGetQuery(con, selectQ )
      tmp$fn <- fn
      tmp$sc <- sc
      tmp$symbolRate <- symbolRate
      tmp$fecOn <- fecOn
      tmp$captureMargin <- captureMargin
      x <- rbind(x, tmp)
    }
  }
  if ( opt == '--pdf' ){
    plotFile=T
    pdf(val, width=pw, height=ph, title=paste(plotType, "v. Senders"))
  }
  if ( opt == '--png' ){
    plotFile=T
    png(val, width=pw, height=ph, units="in", res=200)
  }
  if ( opt == '--plotType'){
    plotType <- val
  }
  if (opt == '--sr'){
    sr <- as.numeric(val)
  }
}
x$fecOn <- factor(x$fecOn)
x$captureMargin <- factor(x$captureMargin)

x$prrFecRX <- x$fecPassed/x$rx

#TODO: group this data by symbolRate, fec, sc, and captureMargin
agg <- ddply(x, .(symbolRate, fecOn, captureMargin, sc), summarise,
  berM=mean(berEst),
  berSD=sd(berEst),
  prrAnyM=mean(prrAny),
  prrAnySD=sd(prrAny),
  prrPassM=mean(prrPass),
  prrPassSD=sd(prrPass),
  prrFecM=mean(prrFec),
  prrFecSD=sd(prrFec),
  prrAnyEM=mean(prrAnyExpected),
  prrAnyESD=sd(prrAnyExpected),
  prrPassEM=mean(prrPassExpected),
  prrPassESD=sd(prrPassExpected),
  prrFecRXM=mean(prrFecRX),
  prrFecRXSD=sd(prrFecRX)
)
pd <- position_dodge(0.2)
if (plotType == 'prrFecRX'){
  print(
    ggplot(agg[agg$symbolRate == sr,], aes(x=sc, y=prrFecRXM,
      color=captureMargin, linetype=fecOn))
    + geom_line(position=pd)
    + geom_point(position=pd, data=x, aes(x=sc, y=prrFecRX, shape=fecOn) )
    + xlab("Number of senders")
    + ylab("PRR")
    + theme_bw()
    + theme(legend.justification=c(0,0), legend.position=c(0,0))
    + scale_shape(solid=FALSE)
    + scale_y_continuous(limits=c(0.0, 1))
  )
}
if (plotType == 'prrAny'){
  print(
    ggplot(agg[agg$symbolRate == sr,], aes(x=sc, y=prrAnyM,
      color=captureMargin, linetype=fecOn))
    + geom_line(position=pd)
#    + geom_point(position=pd, data=x[x$symbolRate==sr,], aes(x=sc, y=prrAny, shape=fecOn) )
    + geom_point(position=pd, aes(x=sc, y=prrFecM, shape=fecOn) )
    + xlab("Number of senders")
    + ylab("PRR")
    + theme_bw()
    + theme(legend.justification=c(0,0), legend.position=c(0,0))
    + scale_shape(solid=FALSE)
    + scale_y_continuous(limits=c(0.0, 1))
  )
}
if (plotType == 'prrPass'){
  print(
    ggplot(agg[agg$symbolRate == sr & agg$fecOn==1,], aes(x=sc, y=prrFecM,
      linetype=captureMargin))
    + geom_line(position=pd)
    + geom_point(position=pd, 
      data=x[x$symbolRate==sr & x$captureMargin==0,], 
      aes(x=sc, y=prrFec),
      size=1.0)
    + xlab("Number of senders")
    + ylab("PRR")
    + theme_bw()
    + theme(panel.grid.major=element_blank(),panel.grid.minor=element_blank())
    + theme(legend.justification=c(1,0), legend.position=c(1,0))
    + scale_shape(solid=FALSE)
    + scale_y_continuous(limits=c(0.75, 1))
    + scale_linetype_manual(name="Capture Margin", 
      breaks=c(0,6,10,20),
      labels=c(0,6,10,20),
      values=c(1,2,3,4)
      )
  )
  print(agg[agg$sc == 5,])
}
if (plotType == 'ber'){
  print(
    ggplot(agg[agg$symbolRate == sr,], aes(x=sc, y=berM,
      color=captureMargin, linetype=fecOn))
    + geom_line(position=pd)
    + geom_point(position=pd, data=x[x$symbolRate==sr,], aes(x=sc, y=berEst, shape=fecOn) )
    + xlab("Number of senders")
    + ylab("BER")
    + theme_bw()
    + theme(legend.justification=c(1,1), legend.position=c(1,1))
    + scale_shape(solid=FALSE)
  )
  print(agg[agg$sc == 5,])
}

if (plotFile){
   g <- dev.off()
}
