plotFile <- F
argc <- length(commandArgs())
argStart <- 1 + which (commandArgs() == '--args')
library(plyr)
library(ggplot2)
library(RSQLite)

selectQRL <- "SELECT 
dest as node, prr
FROM prr_clean a
WHERE dest not in (select node from error_events)
and src=0 and pr="

selectQLR <- "SELECT 
src as node, pr, prr
FROM prr_clean
WHERE src not in (select node from error_events)
and dest=0
and pr="

x <- c()
pr <- 0
direction <- 'lr'
selectQ <- selectQRL
labels <- 'none'
xmin <- 0
xmax <- 1
plotType <- 'cdf'
plotHeight <- 3.5
plotWidth <- 4
for (i in seq(argStart, argc-1)){
  opt <- commandArgs()[i]
  val <- commandArgs()[i+1]
  if (opt == '--dir'){
    direction <- val
    if (direction == 'lr'){
      selectQ <- selectQLR
      print(paste("Using", selectQ))
    }
    if (direction == 'rl'){
      selectQ <- selectQRL
    }
  }
  
  if ( opt == '--db' || opt == '--ndb'){
    fn <- val
    bn <- strsplit(fn, '\\.')[[1]]
    bn <- bn[length(bn)-1]
    if (bn %in% x$bn){
    #  print(paste("Duplicate", fn))
      next
    }    
    lbl <- commandArgs()[i+2]
    pr <- as.numeric(commandArgs()[i+3])
    con <- dbConnect(dbDriver("SQLite"), dbname=fn)
    tmp <- dbGetQuery(con, paste(selectQ, pr))
    #print(paste("Loaded", length(tmp$node), "from", fn))
    if (length(tmp$node) > 0 ){
      tmp$label <- lbl
      tmp$pr <- pr
      tmp$bn <- bn
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
    pdf(val, width=plotWidth, height=plotHeight, title="PRR Distribution(s)")
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
  if (opt == '--plotType'){
    plotType <- val
  }
}
print("raw loaded")
aggByNode <- ddply(x, .(label, node), summarise,
  prr=mean(prr),
  prrSD=sd(prr)
)

aggByLabel <- ddply(aggByNode, .(label), summarize,
  medOfMed=median(prr),
  meanOfMed=mean(prr)
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
  prr=unique(prr),
  ecdf=ecdf(prr)(unique(prr)))

# #TODO add end points at (0,0): this makes the plot barf (I think
# # that it wants observations for each group to be contiguous?
# for (lbl in unique(aggCDF$label)){
#   aggCDF <- rbind(aggCDF, c(lbl, 0, 0))
# }

if (labels == 'bw'){
  print(
    ggplot(aggCDF[aggCDF$label!=5,], aes(x=prr, y=ecdf, linetype=label))
    + geom_line()
    + scale_y_continuous(limits=c(0,1.0))
    + scale_x_continuous(limits=c(xmin,xmax))
    + scale_linetype_manual(name="BW",
      breaks=c(0, 1, 2, 3, 5),
      labels=c(0, 1, 2, 3, 5),
      values=c(3, 4, 2, 5, 1))
    + ylab("CDF")
    + xlab("Packet Reception Ratio")
    + theme_bw()
    + theme(legend.justification=c(0,1), legend.position=c(0,1))
    + theme(panel.grid.major=element_blank(),panel.grid.minor=element_blank())
  )
}
if (labels == 'sel'){
  print(
    ggplot(aggCDF, aes(x=prr, y=ecdf, linetype=label))
    + geom_line()
    + scale_y_continuous(limits=c(0,1.0))
    + scale_x_continuous(limits=c(0,1.0))
    + scale_linetype_manual(name="Metric",
      breaks=c(0, 1, 3, 2, 'flood'),
      labels=c('Last', 'Avg', 'Avg', 'Max', 'Flood'),
      values=c(3, 1, 2, 4, 5))
    + ylab("CDF")
    + xlab("Packet Reception Ratio")
    + theme_bw()
    + theme(legend.justification=c(0,1), legend.position=c(0,1))
    + theme(panel.grid.major=element_blank(),panel.grid.minor=element_blank())
  )
}
if (labels == 'flood'){
  if (plotType == 'histogram'){
    bw <- 0.01
  print(
    ggplot(aggByNode, aes(prr - bw/2))
    + geom_histogram(aes(y=..count../sum(..count..)), 
      fill='white',
      color='black',
      binwidth=bw)
    + xlab("Packet Reception Ratio")
    + ylab("Fraction")
    + scale_x_continuous(limits=c(xmin, xmax))
    + theme_bw()
    + theme(panel.grid.major=element_blank(),panel.grid.minor=element_blank())
  )
  } else if (plotType == 'cdf'){
    print(
      ggplot(aggCDF, aes(x=prr, y=ecdf, linetype=label))
      + geom_line()
      + scale_y_continuous(limits=c(0,1.0))
      + scale_x_continuous(limits=c(xmin,xmax))
      + scale_linetype_manual(name="Metric",
        breaks=c('flood'),
        labels=c('Flood'),
        values=c(1))
      + ylab("CDF")
      + xlab("Packet Reception Ratio")
      + theme_bw()
      + theme(legend.justification=c(0,1), legend.position=c(0,1))
      + theme(panel.grid.major=element_blank(),panel.grid.minor=element_blank())
    )
  }
}
if (labels == 'none'){
  print(
    ggplot(aggCDF, aes(x=prr, y=ecdf, color=label))
    + geom_line()
    + scale_y_continuous(limits=c(0,1.0))
    + scale_x_continuous(limits=c(0,1.0))
    + theme_bw()
    + theme(legend.justification=c(0,1), legend.position=c(0,1))
    + theme(panel.grid.major=element_blank(),panel.grid.minor=element_blank())
  )
}

if ( plotFile){
  g<-dev.off()
}
