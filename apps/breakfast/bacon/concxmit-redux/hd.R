library(ggplot2)
library(plyr)

plotHD <- function(x, fn){
  agg <- ddply(x, .(b, type), summarize,
    ber=mean(d))

  pdf(fn, width=4, height=3.5)
  print(
    ggplot(agg, aes(x=b))
    + geom_line(aes(y=ber/8))
    + scale_y_continuous(limits=c(0, 0.4))
    + theme_bw()
    + xlab("Byte Index")
    + ylab("Bit Error Rate")
#    + scale_color_manual(name="Type", 
#      breaks=c('Interference', 'Conflict'), 
#      labels=c('Inteference', 'Conflict'),
#      values=c('red', 'blue'))
#    + theme(legend.justification=c(1,0), legend.position=c(1,0))
    + theme(legend.position="none")
    + theme(panel.grid.major=element_blank(),panel.grid.minor=element_blank())
  )
  g<-dev.off()

#  pdf(paste(f, 'box', 'pdf', sep='.'))
#  boxplot(d~b, data=x,
#    xlab='Byte Index',
#    ylab='Minimum Hamming Distance',
#    ylim=c(0,4))
#  title(t)
#  g<-dev.off()
  
}

x<-read.csv('data/randomFB.hd', sep=' ', col.names=c('g', 'b', 'd'))
x$type='Interference'
plotHD(x, 'fig/interference_avg.pdf')

y<-read.csv('data/markFB.hd', sep=' ', col.names=c('g', 'b', 'd'))
y$type='Conflict'
plotHD(y, 'fig/conflict_avg.pdf')
