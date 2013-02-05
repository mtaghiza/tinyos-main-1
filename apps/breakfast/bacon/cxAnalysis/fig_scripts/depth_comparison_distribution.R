plotFile <- F
argc <- length(commandArgs())
argStart <- 1 + which (commandArgs() == '--args')
x <- c()
library(plyr)
library(ggplot2)
library(RSQLite)

plotTitle <- 'Distance Comparison'
legendSettings <- 'sim'

selectQ <- "SELECT dest, depth
FROM rx_all 
WHERE src=0
AND ts > (SELECT max(startTS) from prr_bounds)"

sortLabel <- ''
removeOneHop <- 1
hideNaive <- 0
for (i in seq(argStart, argc-1)){
  opt <- commandArgs()[i]
  val <- commandArgs()[i+1]
  if (opt == '--hideNaive'){
    hideNaive <- as.numeric(val)
  }
  if (opt == '--sortLabel'){
    sortLabel <- val
  }
  if ( opt == '--csv'){
    fn <- val
    label <- commandArgs()[i+2]
    tmp <- read.csv(fn)
    tmp$label <- label
    tmp$bn <- fn
    x <- rbind(x, tmp)
  }
  if (opt == '--db' || opt == '--ndb'){
    fn <- val
    bn <- strsplit(fn, '\\.')[[1]]
    bn <- bn[length(bn)-1]
    if (bn %in% x$bn){
    #  print(paste("Duplicate", fn))
      next
    }    
    label <- commandArgs()[i+2]
    con <- dbConnect(dbDriver("SQLite"), dbname=fn)
    tmp <- dbGetQuery(con, selectQ) 
    tmp$label <- label
    tmp$bn <- bn
    x <- rbind(x, tmp)
  }
  if ( opt == '--pdf' ){
    plotFile=T
    pdf(val, width=4, height=3, title=plotTitle)
  }
  if ( opt == '--png' ){
    plotFile=T
    png(val, width=12, height=6, units="in", res=200)
  }
  if (opt == '--labels'){
    legendSettings <- val
  }
  if (opt == '--removeOneHop'){
    removeOneHop <- as.numeric(val)
  }
}

agg <- ddply(x, .(label, dest), summarise,
  depth=mean(depth),
  sd=sd(depth),
  lq=quantile(depth, 0.25),
  uq=quantile(depth, 0.75))

pd <- position_dodge(0.5)

if (removeOneHop){
  agg <- agg[agg$depth > 1.1,]
}


if ( legendSettings == 'sim'){
  plotTitle <- "Simulation v. Actual Distance"
  if (hideNaive){
    agg <- agg[agg$label != 'sim_0x2D_naive',]
  }
  if (sortLabel !=""){
  sortLevels <- agg[agg$label == sortLabel,][order(agg[agg$label == sortLabel,]$depth),]
  agg$sortDest <- factor(agg$dest, levels=sortLevels$dest)
    print(ggplot(agg, aes(x=sortDest, y=depth, shape=label)) 
      + geom_point(position=pd)
  #    + geom_errorbar(aes(ymin=depth-sd, ymax=depth+sd), width=.1, position=pd) 
  #    + geom_errorbar(aes(ymin=depth, ymax=uq), width=.1, position=pd, col='gray') 
      + xlab("")
      + ylab("Distance")
      + scale_shape_manual(name="Setting", 
          breaks=c("0x2D", "sim_0x2D_naive", "sim_0x2D_phy"),
          labels=c("Testbed", "Naive", "Simulation"),
          values=c(3,2,1)) 
      + theme_bw()
      + theme(legend.justification=c(0,1), legend.position=c(0,1))
      + theme(axis.text.x=element_blank(), axis.ticks.x=element_blank())
      + theme(panel.grid.major=element_blank(),panel.grid.minor=element_blank())
    )
  }else{
    print(ggplot(agg, aes(x=reorder(dest, depth), y=depth, shape=label)) 
      + geom_point(position=pd)
  #    + geom_errorbar(aes(ymin=depth-sd, ymax=depth+sd), width=.1, position=pd) 
  #    + geom_errorbar(aes(ymin=depth, ymax=uq), width=.1, position=pd, col='gray') 
      + xlab("")
      + ylab("Distance")
      + scale_shape_manual(name="Setting", 
          breaks=c("0x2D", "sim_0x2D_naive", "sim_0x2D_phy"),
          labels=c("Testbed", "Naive", "Simulation"),
          values=c(3,2,1)) 
      + theme_bw()
      + theme(legend.justification=c(0,1), legend.position=c(0,1))
      + theme(axis.text.x=element_blank(), axis.ticks.x=element_blank())
      + theme(panel.grid.major=element_blank(),panel.grid.minor=element_blank())
    )
  }
  
  joined <- merge(agg[agg$label == '0x2D',], agg[agg$label == 'sim_0x2D_phy',], by=c('dest'))
  print(mean(abs(joined$depth.x-joined$depth.y)))
}

if (legendSettings == 'thresh'){
  plotTitle <- "Distance v. RSSI Threshold"
  meanSDs <- aggregate(sd~label, data=agg, FUN=mean)

  agg$label <- factor(agg$label, levels=sort(unique(as.numeric(agg$label))))
  print(ggplot(agg, aes(x=reorder(dest, depth), y=depth, colour=label)) 
    + geom_point(position=pd)
    + geom_errorbar(aes(ymin=depth-sd, ymax=depth+sd), width=.1, position=pd) 
#    + geom_errorbar(aes(ymin=lq, ymax=uq), width=.1, position=pd) 
    + xlab("")
    + ylab("Distance")
    + scale_colour_hue(name="Threshold (dBm)")
    + theme_bw()
    + theme(legend.justification=c(1,0), legend.position=c(1,0))
    + theme(panel.grid.major=element_blank(),panel.grid.minor=element_blank())
  )
}
if (legendSettings == 'fec'){
  plotTitle <- "Distance v. FEC"
  meanSDs <- aggregate(sd~label, data=agg, FUN=mean)

  agg$label <- factor(agg$label, levels=sort(unique(as.numeric(agg$label))))
  print(ggplot(agg, aes(x=reorder(dest, depth), y=depth, colour=label)) 
    + geom_point(position=pd)
    + geom_errorbar(aes(ymin=depth-sd, ymax=depth+sd), width=.1, position=pd) 
#    + geom_errorbar(aes(ymin=lq, ymax=uq), width=.1, position=pd) 
    + xlab("")
    + ylab("Distance")
    + scale_colour_hue(name="FEC in use")
    + theme_bw()
    + theme(legend.justification=c(1,0), legend.position=c(1,0))
    + theme(panel.grid.major=element_blank(),panel.grid.minor=element_blank())
  )
}

if (legendSettings == 'txp'){
  plotTitle <- "Distance v. TX Power"
  if (sortLabel !=""){
  meanSDs <- aggregate(sd~label, data=agg, FUN=mean)
  sortLevels <- agg[agg$label == sortLabel,][order(agg[agg$label == sortLabel,]$depth),]
  agg$sortDest <- factor(agg$dest, levels=sortLevels$dest)
#  agg$label <- factor(as.numeric(agg$label), levels=sort(unique(as.numeric(agg$label))))
  print(ggplot(agg, aes(x=sortDest, y=depth, shape=label)) 
    + geom_point(position=pd,)
#    + geom_errorbar(aes(ymin=depth-sd, ymax=depth+sd), width=.1, position=pd) 
#    + geom_errorbar(aes(ymin=depth, ymax=uq), width=.1, position=pd, color='gray') 
    + xlab("Node")
    + ylab("Distance")
    + scale_shape_manual(name="TX Power (dBm)",
      breaks=c('0x8D', '0x2D', '0x25'),
      labels=c(0, -6, -12),
      values=c(3, 2, 0))
#     + scale_size_manual(name="TX Power (dBm)",
#       breaks=c('0x8D', '0x2D', '0x25'),
#       labels=c(0, -6, -12),
#       values=c(0.5, 1, 1.5))
    + theme_bw()
    + theme(legend.justification=c(0,1), legend.position=c(0,1))
    + theme(axis.text.x=element_blank(), axis.ticks.x=element_blank())
    + theme(panel.grid.major=element_blank(),panel.grid.minor=element_blank())
  )
  } else{
  print(ggplot(agg, aes(x=reorder(dest,depth), y=depth, shape=label)) 
    + geom_point(position=pd,)
#    + geom_errorbar(aes(ymin=depth-sd, ymax=depth+sd), width=.1, position=pd) 
#    + geom_errorbar(aes(ymin=depth, ymax=uq), width=.1, position=pd, color='gray') 
    + xlab("Node")
    + ylab("Distance")
    + scale_shape_manual(name="TX Power (dBm)",
      breaks=c('0x8D', '0x2D', '0x25'),
      labels=c(0, -6, -12),
      values=c(3, 2, 0))
#     + scale_size_manual(name="TX Power (dBm)",
#       breaks=c('0x8D', '0x2D', '0x25'),
#       labels=c(0, -6, -12),
#       values=c(0.5, 1, 1.5))
    + theme_bw()
    + theme(legend.justification=c(0,1), legend.position=c(0,1))
    + theme(axis.text.x=element_blank(), axis.ticks.x=element_blank())
    + theme(panel.grid.major=element_blank(),panel.grid.minor=element_blank())
  )  }
  
}


if (plotFile){
  g <- dev.off()
}
