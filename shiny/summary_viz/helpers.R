
kdens_legend = function(){
    par(mar = rep(0,4), oma = rep(0,4))
    plot(1,1, axes=FALSE, type='n', xlab='', ylab='', bty='o')
    legend("bottomright", c("75%", "50%", "25%"), bty="o", bg='white',
        lty=c(1,1,1), lwd=4, col=c("purple1", "purple3", "purple4"),
        seg.len=1, box.col='transparent', horiz=TRUE)
}

kdens_plot = function(){

    par(mar = c(4,4,0,0), oma = rep(0,4))

    kernel = kde(na.omit(results[,c('GPP','ER')]))
    ylims = quantile(results$ER, probs=c(0.01, 0.99), na.rm=TRUE)
    xlims = quantile(results$GPP, probs=c(0.01, 0.99), na.rm=TRUE)

    plot(kernel, xlab='', las=1, xaxt='n', ylab='', yaxt='n',
        ylim=ylims, xlim=xlims, display='filled.contour',
        col=c(NA, "purple1", "purple3", "purple4"))
    axis(1, tcl=-0.2, padj=-1)
    axis(2, tcl=-0.2, hadj=0.5, las=1)
    mtext(expression(paste("GPP (g"~O[2]~"m"^"-2"~" d"^"-1"*")")),
        1, line=1.8)
    mtext(expression(paste("ER (g"~O[2]~"m"^"-2"~" d"^"-1"*")")),
        2, line=2)
    abline(0, -1, col='black', lty=3)
}
