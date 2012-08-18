x <- read.csv('data/asym_boxplot.csv')
yl <- c(1,9)

plotFile=F
for (e in commandArgs()){
  if ( e == '--pdf' ){
    plotFile=T
    pdf('fig/asym_boxplot.pdf', width=9, height=6, title="Depth Asymmetry Boxplots")
  }
  if ( e == '--png' ){
    plotFile=T
    png('fig/asym_boxplot.png', width=9, height=6, units="in", res=200)
  }
}

boxplot(depth~root*leaf, data=x[x$lr==0,], border='red', ylim=yl,
 ylab='Distance', xlab='', yaxt='n', pars=list(staplewex=1)
# ,xaxt='n'
 )
axis(side=2, at=1:9)
#par(new=T)
boxplot(depth~root*leaf, data=x[x$lr==1,], border='blue', col='blue',
  pars=list(boxwex=0.1, staplewex=5, cex=0.5), ylim=yl, add=T, yaxt='n'
#  ,xaxt='n'
  )

legend('topleft', c('Root->Leaf', 'Leaf->Root'), text.col=c('red', 'blue'))
title(main="Flood Depth Asymmetry (no retx)")

if ( plotFile){
  g<-dev.off()
}
