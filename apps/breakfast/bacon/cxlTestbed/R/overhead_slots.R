plotFile <- F
argc <- length(commandArgs())
argStart <- 1 + which (commandArgs() == '--args')
library(plyr)
library(ggplot2)
library(RSQLite)

# not sure how ppd/fps ended up being text, but there you have it
selectQ <- "SELECT 1.0*ppd as ppd, 1.0*fps as fps,activeS from overhead_dc_agg"
xmin <- 0
xmax <- 2
ymin <- 0
ymax <- 1

ppd <- 75
x <- c()

ipi <- 9.5
pdfFile <- '' 
maxDepth <- 10.0
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
}
if (ppd == 0){
  ylab <- "Overhead-only Duty Cycle"
}else{
  ylab <- "Active Duty Cycle"
}

if (pdfFile != ''){
  if (size == 'small'){
    pdf(val, width=4, height=3, title=ylab)
  }else{
    pdf(val, width=8, height=4, title=ylab)
  }
}

dayLen <- 60*60*24
probeTime <- (0.005/ipi)*dayLen
wakeupTime <- ipi*maxDepth

x$total <- probeTime + wakeupTime + x$activeS

x <- x[x$ppd == ppd,]

agg <- ddply(x, .(fps), summarize,
  totalMean=mean(total),
  totalMed=median(total),
  totalQ25=quantile(total, 0.25),
  totalQ75=quantile(total, 0.75),
  totalMin=min(total),
  totalMax=max(total)
  )

print(
  ggplot(agg, aes(x=fps, y=totalMean/dayLen))
  + geom_point()
  + geom_errorbar(aes(ymin=totalMin/dayLen, ymax=totalMax/dayLen,
  # + geom_errorbar(aes(ymin=totalQ25/dayLen, ymax=totalQ75/dayLen,
    width=1))
  + ylab(ylab)
  + xlab("Frames per slot")
  + theme_bw()
#  + geom_point(aes(y=totalMean/(60*60*24)), color='black')
#  + geom_point(aes(y=totalQ25/(60*60*24)), color='red')
#  + geom_point(aes(y=totalQ75/(60*60*24)), color='blue')
)

if (plotFile){
  g<- dev.off()
}
