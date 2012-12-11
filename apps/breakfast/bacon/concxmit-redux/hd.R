
plotHD <- function(f, t){
  x<-read.csv(f, sep=' ', col.names=c('g', 'b', 'd'))
  
  pdf(paste(f, 'avg', 'pdf', sep='.'))
  plot(aggregate(d~b, data=x, FUN=mean), type='l',
    xlab='Byte Index',
    ylab='Avg Hamming Distance to Nearest Symbol',
    ylim=c(0,4))
  title(t)
  g<-dev.off()

  pdf(paste(f, 'box', 'pdf', sep='.'))
  boxplot(d~b, data=x,
    xlab='Byte Index',
    ylab='Minimum Hamming Distance',
    ylim=c(0,4))
  title(t)
  g<-dev.off()
  
}
