plotFile <- F
argc <- length(commandArgs())
argStart <- 1 + which (commandArgs() == '--args')
library(plyr)
library(ggplot2)
library(RSQLite)

selectQ <- "SELECT efs, src, dest, prr FROM validation_prr"
xmin <- 0
xmax <- 1.0 
ymin <- 0
ymax <- 0
dir <- 'lr'
efs <- 0
plotType <- 'hist'
size <- 'small'
x <- c()
pdfFile <- '' 
blacklist <- c()
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
  if (opt == '--dir'){
    dir <- val
  }
  if (opt == '--efs'){
    efs <- as.numeric(val)
  }
  if (opt == '--bl'){
    blacklist <- c(blacklist, as.numeric(val))
  }
}

if (efs == 1){
  efsLab <- "FS on"
}else{
  efsLab <- "FS off"
}
if (dir == 'lr'){
  drLab <- "Leaf - Root"
}else{
  drLab <- "Root - Leaf"
}

xlab <- paste(drLab, "PRR,", efsLab)

if (pdfFile != ''){
  if (size == 'small'){
    pdf(val, width=4, height=3, title=paste("Validation",xlab))
  }else{
    pdf(val, width=8, height=4, title=paste("Valdation",xlab))
  }
}

if (dir == 'lr'){
  filtered <- x[x$dest == 0,]
}else{
  filtered <- x[x$src == 0,]
}

filtered <- filtered[filtered$efs == efs,]

for (blNode in blacklist){
  filtered <- filtered[filtered$src!=blNode & filtered$dest!=blNode,]
}

print(paste("PRR", dir, "efs",efs, "blacklist", blacklist))
print(summary(filtered))

bw <- 0.01
print(
  ggplot(filtered, aes(prr-bw/2))
  + geom_histogram(aes(y=..count../sum(..count..)),
    fill='white',
    color='black',
    binwidth=bw)
  + xlab(xlab)
  + ylab("Fraction")
  + scale_x_continuous(limits=c(xmin, xmax))
    + theme_bw()
    + theme(panel.grid.major=element_blank(),panel.grid.minor=element_blank())
)
