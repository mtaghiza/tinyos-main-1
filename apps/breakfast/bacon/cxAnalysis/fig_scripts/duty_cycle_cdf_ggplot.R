plotFile <- F
argc <- length(commandArgs())
argStart <- 1 + which (commandArgs() == '--args')
library(plyr)
library(ggplot2)
library(RSQLite)

selectQ <- "SELECT 
node, dc FROM duty_cycle
WHERE node !=0
AND dc is not null
and node not in (select node from error_events)"

x <- c()
xmin <- -1
xmax <- -1
plotType <- 'cdf'
plotHeight <- 3.5
plotWidth <- 4
for (i in seq(argStart, argc-1)){
  opt <- commandArgs()[i]
  val <- commandArgs()[i+1]
 
  if ( opt == '--db' || opt == '--ndb'){
    fn <- val
    lbl <- commandArgs()[i+2]
    bn <- strsplit(fn, '\\.')[[1]]
    bn <- bn[length(bn)-1]
    if (bn %in% x$bn){
      print(paste("Duplicate", fn))
      next
    }
    con <- dbConnect(dbDriver("SQLite"), dbname=fn)
    tmp <- dbGetQuery(con, selectQ)
    tmp$bn <- bn
    #print(paste("Loaded", length(tmp$node), "from", fn))
    if (length(tmp$node) > 0 ){
      tmp$label <- lbl
      tmp$fn <- fn
      x <- rbind(x, tmp)
    }
  }

  if (opt == '--plotHeight'){
    plotHeight <- as.numeric(val)
  }
  if (opt == '--plotWidth'){
    plotWidth <- as.numeric(val)
  }
  if ( opt == '--pdf' ){
    plotFile=T
    #for whatever rason, latex barfs if this is 4x3
    pdf(val, width=plotWidth, height=plotHeight, title="Duty Cycle Distribution")
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
    plotType <- val
  }
}
print("raw loaded")

# #TODO: what the hell: a few nodes have high duty cycle in several
# # tests, and it's really throwing off the figures
# # 3, 15, 19, 21, 58
# x <- x[x$node !=3,]
# x <- x[x$node !=15,]
# x <- x[x$node !=19,]
# x <- x[x$node !=21,]
# x <- x[x$node !=58,]
aggByNode <- ddply(x, .(label, node), summarise,
  dc=mean(dc),
  dc=sd(dc)
)

aggByLabel <- ddply(aggByNode, .(label), summarize,
  medOfMed=median(dc),
  meanOfMed=mean(dc)
)

#aggByNode <- aggByNode[aggByNode$label=="3",]
print(aggByLabel)
#What this next thing means:
#  group by label
#  prr = list of unique PRRs for group
#  ecdf = ecdf of PRRs for group applied to list of unique PRRs
#         for group
#  (ecdf returns a function, applying it to a PRR gives you its
#    cumulative density)
aggCDF <- ddply(aggByNode, .(label), summarize, 
  dc=unique(dc),
  ecdf=ecdf(dc)(unique(dc)))

# #TODO add end points at (0,0): this makes the plot barf (I think
# # that it wants observations for each group to be contiguous?
# for (lbl in unique(aggCDF$label)){
#   aggCDF <- rbind(aggCDF, c(lbl, 0, 0))
# }
if (plotType == 'cdf'){
  if (xmin == -1 ){
    xmin <- 0
  }
  if (xmax == -1){
    xmax <- max(aggCDF$dc)
  }
  print(
    ggplot(aggCDF, aes(x=100*dc, y=ecdf, linetype=label))
    + geom_line()
    + scale_y_continuous(limits=c(0,1.0))
    + scale_x_continuous(limits=c(100*xmin, 100*xmax))
    + theme_bw()
    + xlab("Duty Cycle")
    + ylab("CDF")
    + theme(legend.position="none")
    + theme(panel.grid.major=element_blank(),panel.grid.minor=element_blank())
  )
}
if (plotType == 'hist'){
  print(
    ggplot(aggByNode, aes(x=dc))
    + geom_histogram(aes(y=..count../sum(..count..)), binwidth=0.001, color='black', fill='gray')
    + xlab("Duty Cycle [0, 1.0]")
    + ylab("Fraction")
    + theme_bw()
    + theme(panel.grid.major=element_blank(),panel.grid.minor=element_blank())
  )
}
if ( plotFile){
  g<-dev.off()
}

