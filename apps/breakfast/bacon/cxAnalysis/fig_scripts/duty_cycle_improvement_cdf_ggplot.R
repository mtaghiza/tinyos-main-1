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
nx <- c()
xmin <- 0
xmax <- 2
for (i in seq(argStart, argc-1)){
  opt <- commandArgs()[i]
  val <- commandArgs()[i+1]
 
  if ( opt == '--ndb'){
    fn <- val
    lbl <- commandArgs()[i+2]
    bn <- strsplit(fn, '\\.')[[1]]
    bn <- bn[length(bn)-1]
    if (bn %in% nx$bn){
      print(paste("Duplicate", fn))
      next
    }
    con <- dbConnect(dbDriver("SQLite"), dbname=fn)
    tmp <- dbGetQuery(con, selectQ)
#    print(paste("Loaded", length(tmp$node), "from", fn))
    if (length(tmp$node) > 0 ){
      tmp$label <- lbl
      tmp$bn <- bn
      nx <- rbind(nx, tmp)
    }
  }
  if ( opt == '--db'){
    fn <- val
    bn <- strsplit(fn, '\\.')[[1]]
    bn <- bn[length(bn)-1]
    if (bn %in% x$bn){
      print(paste("Duplicate", fn))
      next
    }
    lbl <- commandArgs()[i+2]
    con <- dbConnect(dbDriver("SQLite"), dbname=fn)
    tmp <- dbGetQuery(con, selectQ)
#    print(paste("Loaded", length(tmp$node), "from", fn))
    if (length(tmp$node) > 0 ){
      tmp$label <- lbl
      tmp$bn <- bn
      x <- rbind(x, tmp)
    }
  }

  if ( opt == '--pdf' ){
    plotFile=T
    pdf(val, width=4, height=3, title="DCI Comparison CDF")
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
  if (opt == '--labels'){
    labels <- val
  }
}
#print("raw loaded")


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
nAggByNode <- ddply(nx, .(label, node), summarise,
  dc=mean(dc),
  dc=sd(dc)
)
aggByNode <- merge(nAggByNode, aggByNode, by='node', suffixes=c('.ref', '.var'))

aggByNode$label <- aggByNode$label.var
aggByNode$dc <- aggByNode$dc.var/aggByNode$dc.ref

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

if (labels == 'none'){
  print(
    ggplot(aggCDF, aes(x=dc, y=ecdf, color=label))
    + geom_line()
    + geom_vline(xintercept=c(1.0), linetype='dotted')
    + scale_y_continuous(limits=c(0,1.0))
    + scale_x_continuous(limits=c(xmin,xmax))
    + theme_bw()
    + theme(panel.grid.major=element_blank(),panel.grid.minor=element_blank())
  )
}

if (labels == 'bw'){
  print(
    ggplot(aggCDF, aes(x=dc, y=ecdf, linetype=label))
    + geom_line()
    + scale_y_continuous(limits=c(0,1.0))
    + scale_x_continuous(limits=c(xmin,xmax))
    + scale_linetype_manual(name="BW",
      breaks=c(0, 1, 2, 3, 5),
      labels=c(0, 1, 2, 3, 5),
      values=c(3, 4, 2, 5, 1))
    + ylab("CDF")
    + xlab("Fraction of Flood Duty Cycle")
    + geom_vline(xintercept=c(1.0), col='gray')
    + theme_bw()
    + theme(legend.justification=c(0,1), legend.position=c(0,1))
    + theme(panel.grid.major=element_blank(),panel.grid.minor=element_blank())
  )
}

if (labels == 'sel'){
  
  print(
    ggplot(aggCDF, aes(x=dc, y=ecdf, linetype=label))
    + geom_line()
    + scale_y_continuous(limits=c(0,1.0))
    + scale_x_continuous(limits=c(xmin,xmax))
    + scale_linetype_manual(name="Metric",
      breaks=c(0, 1, 3, 2, 'flood'),
      labels=c('Last', 'Avg', 'Avg', 'Max', 'Flood'),
      values=c(3, 1, 2, 4, 5))
    + ylab("CDF")
    + xlab("Fraction of Flood Duty Cycle")
    + geom_vline(xintercept=c(1.0), col='gray')
    + theme_bw()
    + theme(legend.justification=c(1,0), legend.position=c(1,0))
    + theme(panel.grid.major=element_blank(),panel.grid.minor=element_blank())
  )
}

if ( plotFile){
  g<-dev.off()
}


