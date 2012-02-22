args <- c()

#This iterates through the stuff on the command line after --args and
# for every key=value pair, assigns value to key (multiple appearances
# get stored as list)
for (e in commandArgs()[(which(commandArgs() == "--args")+1):length(commandArgs())]){
  ep = strsplit(e,"=",fixed=TRUE)
  name=ep[[1]][1]
  val=ep[[1]][2]
  if(exists(name)){
      assign(name, c(get(name), val))
  } else{
      assign(name, val)
  }
  args <- c(args, name)
}

ma <- function(series, width){
  filter(series, rep(1/width, width), sides=1)
}

rssiPlot <- function(dataFile, pdfOutput='', pngOutput='', maS=1,
    imi=0.11){
  maWindow <- floor(maS/imi)
  if (pdfOutput != ''){
    pdf(pdfOutput)
  } else if(pngOutput != ''){
    png(pngOutput)
  }
  rssi <- read.csv(dataFile, col.names='rssi')
  rssi$ma <-ma(rssi$rssi, maWindow)
  plot(rssi$ma)
  title(dataFile)

  if(pdfOutput != ''){
    garbage<-dev.off()
  }
  if(pngOutput != ''){
    garbage<-dev.off()
  }
  rssi
}
