plotLegend = function(){
    par(mar=rep(0,4), oma=rep(0,4))
    plot(1, 1, type='n', axes=FALSE, xlab='', ylab='')
    legend(x='bottom', legend=c('O2', 'CO2', 'DIC', 'pH'),
        col=c('blue', 'salmon4', 'seagreen4', 'sienna1'), lty=1,
        bty='n', seg.len=.8, adj=.3, horiz=TRUE, lwd=2)
}
