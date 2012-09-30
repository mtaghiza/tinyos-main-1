plotFile <- F
argc <- length(commandArgs())
argStart <- 1 + which (commandArgs() == '--args')
x <- c()
library(plyr)
library(ggplot2)
library(RSQLite)

plotType <- 'prr'
selectQ <- 'SELECT * from ber_summary'
pw <- 8
ph <- 4
for (i in seq(argStart, argc-1)){
  opt <- commandArgs()[i]
  val <- commandArgs()[i+1]
  if (opt == '--aspect'){
    if (val == 'square'){
      pw <- 4
      ph <- 4
    }
  }
  if ( opt == '-f'){
    fn <- val
    con <- dbConnect(dbDriver("SQLite"), dbname=fn)
    sc <- as.numeric(commandArgs()[i+2])
    label <- commandArgs()[i+3]
    tmp <- dbGetQuery(con, selectQ )
    tmp$fn <- fn
    tmp$label <- label
    tmp$sc <- sc
    x <- rbind(x, tmp)
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
}

agg <- ddply(x, .(label, sc), summarise,
  berM=mean(berEst),
  berSD=sd(berEst),
  prrAnyM=mean(prrAny),
  prrAnySD=sd(prrAny),
  prrPassM=mean(prrPass),
  prrPassSD=sd(prrPass),
  prrAnyEM=mean(prrAnyExpected),
  prrAnyESD=sd(prrAnyExpected),
  prrPassEM=mean(prrPassExpected),
  prrPassESD=sd(prrPassExpected)
)
agg <- agg[agg$label != 'nocap',]
agg <- agg[agg$label != 4,]
x <- x[x$label != 'nocap',]
x <- x[x$label != 4,]
agg$label <- factor(agg$label, levels=sort(unique(as.numeric(agg$label))))
x$label <- factor(x$label, levels=sort(unique(as.numeric(x$label))))
pd <- position_dodge(0.1)


if (plotType == 'prrAny'){
  print(
    ggplot(agg, aes(x=sc, y=prrAnyM, colour=label))
    + geom_line(position=pd)
    + scale_colour_hue(name="Capture Margin (dBm) ")
    + geom_point(data=x, aes(x=sc, y=prrAny), position=pd)
    + ggtitle("Packet Reception Ratio (incl. CRC failures) v. Senders")
    + xlab("Number of senders")
    + ylab("PRR (0,1.0)")
    + scale_y_continuous(limits=c(0.0,1))
    + theme_bw()
    + theme(legend.justification=c(0,0), legend.position=c(0,0))
  )
}
if (plotType == 'prrPass'){
  print(
    ggplot(agg, aes(x=sc, y=prrPassM, colour=label))
    + geom_line(position=pd)
    + scale_colour_hue(name="Capture Margin (dBm) ")
    + geom_point(data=x, aes(x=sc, y=prrPass), position=pd)
    + ggtitle("Packet Reception Ratio v. Senders")
    + xlab("Number of senders")
    + ylab("PRR (0,1.0)")
    + scale_y_continuous(limits=c(0.0,1))
    + theme_bw()
    + theme(legend.justification=c(0,0), legend.position=c(0,0))
  )
}
if (plotType == 'ber'){
  print(
    ggplot(agg, aes(x=sc, y=berM, colour=label))
    + geom_line(position=pd)
    + geom_point(position=pd)
    + scale_colour_hue(name="Capture Margin (dBm) ")
    + ggtitle("Bit Error Rate v. Senders")
    + xlab("Number of senders")
    + ylab("Bit error rate (0,1.0)")
    + theme_bw()
    + theme(legend.justification=c(1,1), legend.position=c(1,1))
  )
}
if (plotType == 'sc'){
  print(
    ggplot(agg, aes(x=sc, y=prrAnyM, colour=label))
    + geom_line(position=pd) 
    + geom_point(aes(x=sc, y=prrAnyEM), position=pd)
    + theme_bw()
  )
}

if  (plotFile){
  g <- dev.off()
}
