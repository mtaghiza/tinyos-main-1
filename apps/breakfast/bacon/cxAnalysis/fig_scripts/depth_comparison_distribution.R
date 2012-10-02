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


for (i in seq(argStart, argc-1)){
  opt <- commandArgs()[i]
  val <- commandArgs()[i+1]
  if ( opt == '--csv'){
    fn <- val
    label <- commandArgs()[i+2]
    tmp <- read.csv(fn)
    tmp$label <- label
    x <- rbind(x, tmp)
  }
  if (opt == '--db'){
    fn <- val
    label <- commandArgs()[i+2]
    con <- dbConnect(dbDriver("SQLite"), dbname=fn)
    tmp <- dbGetQuery(con, selectQ) 
    tmp$label <- label
    x <- rbind(x, tmp)
  }
  if ( opt == '--pdf' ){
    plotFile=T
    pdf(val, width=12, height=6, title=plotTitle)
  }
  if ( opt == '--png' ){
    plotFile=T
    png(val, width=12, height=6, units="in", res=200)
  }
  if (opt == '--labels'){
    legendSettings <- val
  }
}

agg <- ddply(x, .(label, dest), summarise,
  depth=mean(depth),
  sd=sd(depth),
  lq=quantile(depth, 0.25),
  uq=quantile(depth, 0.75))

pd <- position_dodge(0.5)
agg <- agg[agg$depth > 1.1,]


if ( legendSettings == 'sim'){
  plotTitle <- "Simulation v. Actual Distance"
  print(ggplot(agg, aes(x=reorder(dest, depth), y=depth, colour=label)) 
    + geom_point(position=pd)
    + geom_errorbar(aes(ymin=depth-sd, ymax=depth+sd), width=.1, position=pd) 
  #  + geom_errorbar(aes(ymin=lq, ymax=uq), width=.1, position=pd) 
    + xlab("Node ID")
    + ylab("Distance")
    + ggtitle(plotTitle) 
    + scale_colour_hue(name="Dataset", 
        breaks=c("testbed", "sim_0.4_10_ind_0", "sim_0.4_10_ind_1"),
        labels=c("Testbed", "Simulation ( + interference)", "Simulation (no interference)")) 
    + theme_bw()
    + theme(legend.justification=c(1,0), legend.position=c(1,0))
  )
}

if (legendSettings == 'thresh'){
  plotTitle <- "Distance v. RSSI Threshold"
  meanSDs <- aggregate(sd~label, data=agg, FUN=mean)

  agg$label <- factor(agg$label, levels=sort(unique(as.numeric(agg$label))))
  print(ggplot(agg, aes(x=reorder(dest, depth), y=depth, colour=label)) 
    + geom_point(position=pd)
    + geom_errorbar(aes(ymin=depth-sd, ymax=depth+sd), width=.1, position=pd) 
#    + geom_errorbar(aes(ymin=lq, ymax=uq), width=.1, position=pd) 
    + xlab("Node ID")
    + ylab("Distance")
    + ggtitle(plotTitle) 
    + scale_colour_hue(name="Threshold (dBm)")
    + theme_bw()
    + theme(legend.justification=c(1,0), legend.position=c(1,0))
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
    + xlab("Node ID")
    + ylab("Distance")
    + ggtitle(plotTitle) 
    + scale_colour_hue(name="FEC in use")
    + theme_bw()
    + theme(legend.justification=c(1,0), legend.position=c(1,0))
  )
}


if (plotFile){
  g <- dev.off()
}
