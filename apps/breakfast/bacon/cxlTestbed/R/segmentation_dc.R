#plot mtFrac against patchSize or shorten 
# - or use symbol/color for non-axis condition
#do routers or leaf nodes separately

plotFile <- F
argc <- length(commandArgs())
argStart <- 1 + which (commandArgs() == '--args')
library(plyr)
library(ggplot2)
library(RSQLite)

selectQ <- "SELECT * FROM seg_dc_final;";

xmin <- 0
xmax <- 2
ymin <- 0
ymax <- 1
plotType <- 'scatter'
plotData <- 'relative'
size <- 'small'
ppd <- 75
router<-0
efs <- 0
x<-c()
pdfFile <- ''
ipi <- 9.5
maxDepth <- 10.0
plotPatchSize <- 1
bw <- 0.02

lpos <- c(1,1)
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
    x <- rbind(x, dbGetQuery(con, selectQ))
  }

  if ( opt == '--pdf' ){
    plotFile=T
    pdfFile <- val
  }
  if ( opt == '--png' ){
    plotFile=T
    png(val, width=9, height=6, units="in", res=200)
  }
  if (opt == '--router'){
    router <- as.numeric(val)
  }
  if (opt == '--ipi'){
    ipi <- as.numeric(val)
  }
  if (opt == '--ppd'){
    ppd <- as.numeric(val)
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
  if (opt=='--lpos'){
    if (val == 'ur'){
      lpos <- c(1,1)
    }else if (val == 'ul'){
      lpos <- c(0,1)
    }else if (val == 'br'){
      lpos <- c(1,0)
    }else if (val == 'bl'){
      lpos <- c(0,0)
    }
  }
  if (opt == '--plotPatchSize'){
    plotPatchSize <- as.numeric(val)
  }
  if (opt == '--plotData'){
    plotData <- val
  }
}

probeTime <- (0.005/ipi)*60*60*24
wakeupTime <- ipi*maxDepth

x$flatTotal <- (probeTime+wakeupTime)+x$flatActive
x$mtTotal   <- (probeTime+wakeupTime)*(x$router+1)+x$mtActive
x$mtFracFinal <- x$mtTotal/x$flatTotal

print("Overhead DC Leaf:")
print((probeTime+wakeupTime)/(24*60*60))
print("Overhead DC Router:")
print(2*(probeTime+wakeupTime)/(24*60*60))
if (ppd == 0){
  ylab <- "Idle"
}else{
  ylab <- "Active"
}

if (router == 1){
  ylab <- paste(ylab, "Router Duty Cycle (rel. to flat) [0, 1.0]")
}else{
  ylab <- paste(ylab, "Leaf Duty Cycle (rel. to flat) [0, 1.0]")
}

print(x[x$router == 1,])

if (pdfFile != ''){
  if (size == 'small'){
    pdf(val, width=4, height=3, title=ylab)
  }else{
    pdf(val, width=8, height=4, title=ylab)
  }
  print("Plotting to")
  print(pdfFile)
}

agg <- ddply(x, .(router, ppd), summarize,
  mtFrac =mean(mtFrac),
  mtFracFinal =mean(mtFracFinal),
  mtTotal = mean(mtTotal)/(24*60*60),
  flatTotal = mean(flatTotal)/(24*60*60),
  flatActive = mean(flatActive)/(24*60*60),
  mtActive = mean(mtActive)/(24*60*60)
  )
print(agg)

agg <- ddply(x, .(ppd), summarize,
  mtFrac =mean(mtFrac),
  mtFracFinal =mean(mtFracFinal),
  mtTotal = mean(mtTotal)/(24*60*60),
  flatTotal = mean(flatTotal)/(24*60*60),
  flatActive = mean(flatActive)/(24*60*60),
  mtActive = mean(mtActive)/(24*60*60)
)
print(agg)


x <- x[x$ppd == ppd,]
x <- x[x$router == router,]

if (plotType == 'scatter'){
if (plotPatchSize == 1){
  print(
    ggplot(x, aes(x=1/shorten, y=mtFracFinal, size=patchSize))
    + scale_y_continuous(limits=c(ymin, ymax))
    + scale_x_continuous(limits=c(xmin, xmax))
    + geom_point(alpha=0.75)
    + theme_bw()
    + theme(legend.justification=lpos, legend.position=lpos)
    + scale_size_continuous(name="Patch Size",
      breaks=c(1, 3, 5, 7, 8))
    + xlab("Sink Distance (rel. to flat)")
    + ylab(ylab)
  #  + theme(panel.grid.major=element_blank(),panel.grid.minor=element_blank())
  )
}else{
  if (plotData == 'relative'){
    print(
      ggplot(x, aes(x=1/shorten, y=mtFracFinal))
      + scale_y_continuous(limits=c(ymin, ymax))
      + scale_x_continuous(limits=c(xmin, xmax))
      + geom_point(alpha=0.75)
      + theme_bw()
      + theme(legend.justification=lpos, legend.position=lpos)
      + xlab("Sink Distance (rel. to flat)")
      + ylab(ylab)
    #  + theme(panel.grid.major=element_blank(),panel.grid.minor=element_blank())
    )
  }else if (plotData == 'mt'){
    print(
      ggplot(x, aes(x=1/shorten, y=mtTotal))
      + scale_y_continuous(limits=c(ymin, ymax))
      + scale_x_continuous(limits=c(xmin, xmax))
      + geom_point(alpha=0.75)
      + theme_bw()
      + theme(legend.justification=lpos, legend.position=lpos)
      + xlab("Sink Distance (rel. to flat)")
      + ylab(ylab)
    #  + theme(panel.grid.major=element_blank(),panel.grid.minor=element_blank())
    )
  }else if (plotData == 'flat'){
    print(
      ggplot(x, aes(x=1/shorten, y=flatTotal))
      + scale_y_continuous(limits=c(ymin, ymax))
      + scale_x_continuous(limits=c(xmin, xmax))
      + geom_point(alpha=0.75)
      + theme_bw()
      + theme(legend.justification=lpos, legend.position=lpos)
      + xlab("Sink Distance (rel. to flat)")
      + ylab(ylab)
    #  + theme(panel.grid.major=element_blank(),panel.grid.minor=element_blank())
    )
  }
}
} else if (plotType == 'histogram'){
  if (plotData == 'relative'){
    print(
      ggplot(x, aes((1.0-mtFracFinal)-bw/2))
      + geom_histogram(aes(y=..count../sum(..count..)), binwidth=bw)
      + theme_bw()
      + xlab("DC Improvement")
      + ylab("Fraction of nodes")
    )
  }
}

if (plotFile){
  g <-dev.off()
}
