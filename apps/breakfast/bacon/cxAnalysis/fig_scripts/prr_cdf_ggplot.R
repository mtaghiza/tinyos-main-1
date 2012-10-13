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
    lbl <- commandArgs()[i+2]
    pr <- as.numeric(commandArgs()[i+3])
    con <- dbConnect(dbDriver("SQLite"), dbname=fn)
    tmp <- dbGetQuery(con, paste(selectQ, pr))
    print(paste("Loaded", length(tmp$node), "from", fn))
    if (length(tmp$node) > 0 ){
      tmp$label <- lbl
      tmp$pr <- pr
      x <- rbind(x, tmp)
    }
  }

  if ( opt == '--pdf' ){
    plotFile=T
    pdf(val, width=9, height=6, title="PRR Comparison CDF")
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
    ggplot(aggCDF, aes(x=prr, y=ecdf, color=label))
    + geom_line()
    + scale_y_continuous(limits=c(0,1.0))
    + scale_x_continuous(limits=c(0,1.0))
    + scale_colour_hue(name="Boundary Width")
    + theme_bw()
    + theme(legend.justification=c(0,1), legend.position=c(0,1))
  )
}
if (labels == 'sel'){
  print(
    ggplot(aggCDF, aes(x=prr, y=ecdf, color=label))
    + geom_line()
    + scale_y_continuous(limits=c(0,1.0))
    + scale_x_continuous(limits=c(0,1.0))
    + scale_colour_hue(name="Selection Method",
      breaks=c(0, 1, 2, 'flood'),
      labels=c('Last', 'Avg', 'Max', 'Flood'))
    + theme_bw()
    + theme(legend.justification=c(0,1), legend.position=c(0,1))
  )
}
if (labels == 'none'){
  print(
    ggplot(aggCDF, aes(x=prr, y=ecdf, color=label))
    + geom_line()
    + scale_y_continuous(limits=c(0,1.0))
    + scale_x_continuous(limits=c(0,1.0))
    + theme_bw()
    + theme(legend.justification=c(0,1), legend.position=c(0,1))
  )
}

if ( plotFile){
  g<-dev.off()
}
