plotCdf<-function(ds, xl, yl, t, plotPdf=F, pdfFile=""){
  if (plotPdf){
    print(paste("Plotting to", pdfFile))
    pdf(pdfFile, title=t)
  }else{
    print("skip plot")
  }
  plot(
    sort(ds),
    (0:(length(ds)-1))/(length(ds)-1), 
    type = 'l',
    xlab=xl,
    ylab=yl,
    xlim=c(0,1))
  title(t)
  if (plotPdf){
    g<-dev.off()
  }
}


