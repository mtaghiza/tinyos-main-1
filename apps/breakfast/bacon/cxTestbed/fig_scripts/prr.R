args <- c()

plotPdf <- F
outPrefix <- ""
for (e in commandArgs()[(which(commandArgs() == "--args")+1):length(commandArgs())]){
  ep = strsplit(e,"=",fixed=TRUE)
  name=ep[[1]][1]
  val=ep[[1]][2]

  if (name == 'dataFile'){
    dataFile <- val
  }
  if (name == 'outPrefix'){
    outPrefix <- val
  }
  if (name == 'plotPdf'){
    plotPdf <- as.logical(val)
  }
  if (name=='label'){
    label <- val
  }
}

source('fig_scripts/cdf.R')
x <- read.csv(dataFile, sep=',', header=T)

ds <- x$src_to_dest
xl <- "PRR [0,1.0]"
yl <- "P [0, 1.0]"
t <- "Root->Leaf PRR"
plotCdf(ds, xl, yl, paste(label, t, sep=' '), plotPdf, paste(outPrefix, 'prr_rl','pdf', sep='.'))

devAskNewPage(T)
ds <- x$dest_to_src
xl <- "PRR [0, 1.0]"
yl <- "P [0, 1.0]"
t <- "Leaf->Root PRR"
plotCdf(ds, xl, yl, paste(label, t, sep=' '), plotPdf, paste(outPrefix, 'prr_lr', 'pdf', sep='.'))
print(paste(dataFile, median(ds)))

ds <- x$src_to_dest - x$dest_to_src
xl <- "PRR (root,leaf) - (leaf, root)"
yl <- "P [0, 1.0]"
t <- "PRR asymmetry"
plotCdf(ds, xl, yl, paste(label, t, sep=' '), plotPdf, paste(outPrefix, 'prr_asym', 'pdf', sep='.'))

devAskNewPage(F)
