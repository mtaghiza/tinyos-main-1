library(ggplot2)

plotHist<- function(x, f, cycleLen){
  pdf(paste(f, cycleLen, 'pdf', sep='.'), width=4, height=3.5,
    title=paste('Error Positions (', f, cycleLen, ')'))
  x$ppos <- x$pos %% cycleLen
  print(
    ggplot(x, aes(x=ppos))
    + geom_histogram(aes(y=..count../sum(..count..)), 
        breaks=0:cycleLen, color='black', fill='gray')
    + scale_x_continuous(limits=c(0, max(x$ppos)+1))
    + theme_bw()
    + xlab("Bit Position")
    + ylab("Fraction of Errors")
    + theme(panel.grid.major=element_blank(),panel.grid.minor=element_blank())
  )
  g <- dev.off()
}

#par(ask=T)
allPlots <- function(f){
  x <- read.csv(f, sep=' ', col.names=c('g', 'pos'))
#  plotHist(x, f, max(x$pos))
#  plotHist(x, f, 8)
  plotHist(x, f, 16)
}

allPlots('data/sameFB.ep')
#allPlots('data/randomFB.ep')
par(ask=F)
