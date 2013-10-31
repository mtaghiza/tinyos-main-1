plotFile <- F
argc <- length(commandArgs())
argStart <- 1 + which (commandArgs() == '--args')
library(plyr)
library(ggplot2)
library(RSQLite)

selectQ <- "SELECT efs, node, activeS FROM flat_active_indiv";

activeDC <- c()
xmin <- 0
xmax <- -1
ymin <- 0
ymax <- 0
plotType <- 'cdf'
size <- 'small'
efs <- 0
for (i in seq(argStart, argc-1)){
  opt <- commandArgs()[i]
  val <- commandArgs()[i+1]
  if (opt =='--size'){
    size <- val
  }
  if ( opt == '--plotType'){
    plotType <- val
  }
  if ( opt == '--db'){
    fn <- val
    con <- dbConnect(dbDriver("SQLite"), dbname=fn)
    activeDC <- rbind(activeDC, dbGetQuery(con, selectQ))
  }

  if ( opt == '--pdf' ){
    plotFile=T
    if (size == 'small'){
      pdf(val, width=4, height=3, title="Flat network DC")
    }else{
      pdf(val, width=8, height=4, title="Flat network DC")
    }
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
  if (opt == '--ymin'){
    ymin <- as.numeric(val)
  }
  if (opt == '--ymax'){
    ymax <- as.numeric(val)
  }
  if (opt == '--efs'){
    efs <- as.numeric(val)
  }
  if(opt == '--bw'){
    bw <- as.numeric(val)
  }
}

aggByEfs <- ddply(activeDC, .(efs), summarise,
  activeS=mean(activeS)
)
aggByNode <- ddply(activeDC, .(efs, node), summarise,
  activeS=mean(activeS)
)

aggByEfs$dcFree <- aggByEfs$activeS/(50*60)
aggByEfs$dcWake <- (10+aggByEfs$activeS)/(50*60)

aggByNode$dcFree <- aggByNode$activeS/(50*60)
aggByNode$dcWake <- (10+aggByNode$activeS)/(50*60)

print(aggByEfs)

aggCDF <- ddply(aggByNode, .(efs), summarize,
  dc=unique(dcWake),
  ecdf=ecdf(dcWake)(unique(dcWake)))

if (plotType == 'cdf'){
  xmin <- 0
  xmax <- max(aggCDF$dc)
  print(
    ggplot(aggCDF, aes(x=100*dc, y=ecdf, linetype=efs))
    + geom_line()
    + scale_y_continuous(limits=c(0,1.0))
    + scale_x_continuous(limits=c(100*xmin, 100*xmax))
    + theme_bw()
    + xlab("Duty Cycle")
    + ylab("CDF")
    + theme(legend.position=c(0,1), legend.justification=c(0,1))
    + scale_linetype_manual(name='CXFS',
      breaks=c(0,1),
      labels=c("Off", "On"),
      values=c(1,2))
    + theme(panel.grid.major=element_blank(),panel.grid.minor=element_blank())
  )
} 

if (plotType == 'hist'){
  if (bw == -1){
    bw <- 0.001
  }
  if (xmax == -1){
    xmax <- max(aggByNode[aggByNode$efs==efs,]$dcWake)
  }
  print(
    ggplot(aggByNode[aggByNode$efs==efs,], aes(x=dcWake))
    + geom_histogram(aes(y=..count../sum(..count..)), binwidth=bw, color='black', fill='gray')
    + xlab("Duty Cycle [0, 1.0]")
    + ylab("Fraction")
    + scale_x_continuous(limits=c(xmin, xmax))
    + theme_bw()
    + theme(panel.grid.major=element_blank(),panel.grid.minor=element_blank())
  )
}

if ( plotFile){
  g<-dev.off()
}
