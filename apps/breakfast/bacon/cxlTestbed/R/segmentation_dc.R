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
xmax <- -1
ymin <- 0
ymax <- 0
plotType <- 'cdf'
size <- 'small'
ppd <- 0
router<-0
efs <- 0
x<-c()
pdfFile <- ''
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
}

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

if (pdfFile != ''){
  if (size == 'small'){
    pdf(val, width=4, height=3, title=ylab)
  }else{
    pdf(val, width=8, height=4, title=ylab)
  }
}

agg <- ddply(x, .(router, ppd), summarize,
  mtFrac =mean(mtFrac))
print(agg)
x <- x[x$ppd == ppd,]
x <- x[x$router == router,]

print(
  ggplot(x, aes(x=1/shorten, y=mtFrac, size=patchSize))
  + scale_y_continuous(limits=c(ymin, ymax))
  + geom_point(alpha=0.75)
  + theme_bw()
  + theme(legend.justification=lpos, legend.position=lpos)
  + scale_size_continuous(name="Patch Size",
    breaks=c(1, 3, 5, 7, 8))
  + xlab("Sink Distance (rel. to flat)")
  + ylab(ylab)
#  + theme(panel.grid.major=element_blank(),panel.grid.minor=element_blank())
)

if (plotFile){
  g <-dev.off()
}
