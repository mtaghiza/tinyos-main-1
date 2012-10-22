argc <- length(commandArgs())
argStart <- 1 + which (commandArgs() == '--args')

xMin <- 0
xMax <- 0
scheds<-c()
losses<-c()
recovers<-c()
for (i in seq(argStart, argc-1)){
  opt <- commandArgs()[i]
  val <- commandArgs()[i+1]
  if (opt == '-f'){
    fn <- val
  }
  if (opt == '-min'){
    xMin <- as.numeric(val)
  }
  if (opt == '-max'){
    xMax <- as.numeric(val)
  }
  if (opt == '-l'){
    losses <- c(losses, as.numeric(val))
  }
  if (opt == '-r'){
    recovers <- c(recovers, as.numeric(val))
  }
  if (opt == '-s'){
    scheds <- c(scheds, as.numeric(val))
  }
}

x <- read.csv(fn)
if (xMin == 0){
  xMin <- min(x$absolute)
}
if (xMax == 0){
  xMax <- max(x$absolute)
}

sx <- x
plot(sx$absolute, sx$delta, type='l', xlim=c(xMin, xMax))

for (l in losses){
  lines(c(l, l), c(0, 1), col='red')
}
for (r in recovers){
  lines(c(r, r), c(0, 1), col='green')
}
for (s in scheds){
  lines(c(s, s), c(0, 1), col='blue')
}
