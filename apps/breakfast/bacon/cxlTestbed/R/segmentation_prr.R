
plotFile <- F
argc <- length(commandArgs())
argStart <- 1 + which (commandArgs() == '--args')
library(plyr)
library(ggplot2)
library(RSQLite)


selectQ <-"SELECT src, tunneledPrr, tunneledPrr-flatPrr as
tunneledChange FROM seg_prr_final"

plotType <- 'hist'
xmin <- -0.045
xmax <- 0.045
ymin <- 0
ymax <- 1
size <- 'small'
blacklist <- c()
pdfFile <- '' 
bw <- 0.005

x<-c()
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
}
if (pdfFile != ''){
  if (size == 'small'){
    pdf(val, width=4, height=3, title="Tunneled PRR Change")
  }else{
    pdf(val, width=8, height=4, title="Tunneled PRR Change")
  }
}

for (blNode in blacklist){
  x <- x[x$src!=blNode,]
}

print(summary(x))

print(
  ggplot(x, aes(tunneledChange-bw/2))
  + geom_histogram(aes(y=..count../sum(..count..)),
    fill='white',
    color='black',
    binwidth=bw)
  + xlab("Tunneled PRR Change")
  + ylab("Fraction")
  + scale_x_continuous(limits=c(xmin, xmax))
  + scale_y_continuous(limits=c(ymin, ymax))
  + theme_bw()
  + theme(panel.grid.major=element_blank(),panel.grid.minor=element_blank())
)

