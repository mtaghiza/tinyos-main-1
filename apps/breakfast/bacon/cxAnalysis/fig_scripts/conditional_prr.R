library(RSQLite)

fn <- ''
plotFile <- F
argc <- length(commandArgs())
argStart <- 1 + which (commandArgs() == '--args')
x <- c()

for (i in seq(argStart, argc-1)){
  opt <- commandArgs()[i]
  val <- commandArgs()[i+1]
  if ( opt == '-f'){
    fn <- val
    lbl <- commandArgs()[i+2]
  }
  if ( opt == '--pdf' ){
    plotFile=T
    pdf(val, width=9, height=9, title="Conditional PRR Matrix")
  }
  if ( opt == '--png' ){
    plotFile=T
    png(val, width=9, height=9, units="in", res=200)
  }
}

con <- dbConnect(dbDriver("SQLite"), dbname=fn)
refNodes <- 
  dbGetQuery(con, "SELECT distinct rd from conditional_prr order by rd")
x <- dbGetQuery(con, "SELECT cd, rd, condPrr from conditional_prr where cd in (select distinct rd from conditional_prr)")


library(lattice)
#Build the horizontal and vertical axis information
hor <- refNodes$rd
ver <- refNodes$rd

#Build the fake correlation matrix
nrowcol <- length(ver)
cor <- matrix(0, nrow=nrowcol,
ncol=nrowcol, dimnames = list(hor, ver))
for (i in seq(dim(x)[1])){
  cur <- x[i,]
  cd <- cur$cd
  rd <- cur$rd
  prr <- cur$condPrr
  cor[as.character(rd), as.character(cd)] = prr
}

#Build the plot
rgb.palette <- colorRampPalette(c("blue", "yellow"), space = "rgb")
levelplot(cor, main="PRR(var|ref received)", xlab="Reference", ylab="Variable", col.regions=rgb.palette(120), cuts=100, at=seq(0,1,0.01))
if (plotFile){
  g<- dev.off()
}

