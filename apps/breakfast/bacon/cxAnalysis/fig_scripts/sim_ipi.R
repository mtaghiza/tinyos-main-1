plotFile <- F
argc <- length(commandArgs())
argStart <- 1 + which (commandArgs() == '--args')
library(plyr)
library(ggplot2)

x <- c()
xmin <- -1
xmax <- -1
plotType <- 'diameter'
for (i in seq(argStart, argc-1)){
  opt <- commandArgs()[i]
  val <- commandArgs()[i+1]
 
  if ( opt == '--txt' ){
    fn <- val
    aspectRatio <- as.numeric(commandArgs()[i+2])
    density <- as.numeric(commandArgs()[i+3])
    numNodes <- as.numeric(commandArgs()[i+4])
    tmp <- read.csv(fn, sep=' ',
      col.names=c('node', 'avgDepth', 'ipi','floodIpi' ), 
      header=F)
    print(paste("Loaded", length(tmp$node), "from", fn))
    if (length(tmp$node) > 0 ){
      tmp$fn <- fn
      tmp$nodeCount <- length(tmp$node)
      tmp$aspectRatio <- aspectRatio
      tmp$density <- density
      tmp$diameter <- max(tmp$avgDepth)
      x <- rbind(x, tmp)
    }
  }

  if ( opt == '--pdf' ){
    plotFile=T
    pdf(val, width=4, height=3, title="Throughput v. Diameter")
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
  if (opt == '--plotType'){
    plotType = val
  }
}
print("raw loaded")

x$aspectRatioF = factor(x$aspectRatio)
agg <- ddply(x, .(nodeCount, aspectRatioF, density), summarize,
  ipiRatio=mean(floodIpi/ipi),
  diameter=mean(diameter)
)

if (plotType == 'nodeCount'){
  print(
    ggplot(agg, 
      aes(x=nodeCount, y=ipiRatio, color=aspectRatioF))
    + geom_line()
    + theme_bw()
    + ylab("Normalized RR Burst Throughput")
    + xlab("Node Count")
    + theme(legend.justification=c(0,1), legend.position=c(0,1))
    + scale_colour_hue(name="Network Shape")
  )
}
if (plotType == 'diameter'){
  x$counter <- 1
  abd <- ddply(x, .(diameter, aspectRatioF, density), summarize,
    ipiRatio= mean(floodIpi/ipi),
    nodeCount= mean(nodeCount),
    instanceCount=sum(counter)
    )
  abd <- abd[abd$diameter > 3,]
  print(
    ggplot(abd,
      aes(x=diameter, y=ipiRatio, linetype=aspectRatioF))
    + geom_line()
    + theme_bw()
    + ylab("Normalized RR Burst Throughput")
    + xlab("Network Diameter")
    + theme(legend.justification=c(0,1), legend.position=c(0,1))
    + scale_linetype_manual(name="Network Shape",
      breaks=c(1,4),
      labels=c('Square', 'Rectangle'),
      values=c(1,2))
    + theme(panel.grid.major=element_blank(), panel.grid.minor=element_blank())
  )
}
