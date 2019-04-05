
kdens_legend = function(is_overlay){
    par(mar = rep(0,4), oma = rep(0,4))
    plot(1,1, axes=FALSE, type='n', xlab='', ylab='', bty='o')
    legend("bottomright", c("75%", "50%", "25%"), bty="o", bg='white',
        lty=c(1,1,1), lwd=4, col=c("purple1", "purple3", "purple4"),
        seg.len=1, box.col='transparent', horiz=TRUE, title='Overall density')

    if(is_overlay){
        legend("bottomleft", c("75%", "50%", "25%"), bty="o", bg='white',
            lty=c(1,1,1), lwd=4, col=c("red", "orange", "yellow"),
            seg.len=1, box.col='transparent', horiz=TRUE,
            title='Density of subset')
    }
}

kdens_plot = function(overlay){

    par(mar=c(4,4,0,0), oma=rep(0,4), xaxs='i', yaxs='i')

    #plot limits
    # if(! overlay %in% c('', 'None')){
    if(is.null(overlay) || (length(overlay) == 1 && overlay == 'None')){
        ylims = quantile(results$ER, probs=c(0.01, 0.99), na.rm=TRUE)
        xlims = quantile(results$GPP, probs=c(0.01, 0.99), na.rm=TRUE)
    } else {
        overlay = overlay[overlay != 'None']
        regionsite = sapply(overlay, strsplit, '_')
        regions = unique(sapply(regionsite, function(x) x[1]))
        sites = unique(sapply(regionsite, function(x) x[2]))
        subset_i = results$region %in% regions & results$site %in% sites
        yla = quantile(results$ER[subset_i], probs=c(0.03, 0.97), na.rm=TRUE)
        xla = quantile(results$GPP[subset_i], probs=c(0.03, 0.97), na.rm=TRUE)
        ylb = quantile(results$ER, probs=c(0.01, 0.99), na.rm=TRUE)
        xlb = quantile(results$GPP, probs=c(0.01, 0.99), na.rm=TRUE)
        ylims = range(c(yla, ylb))
        xlims = range(c(xla, xlb))
    }

    #overall plot
    kernel = kde(na.omit(results[,c('GPP','ER')]))
    plot(kernel, xlab='', las=1, xaxt='n', ylab='', yaxt='n',
        ylim=ylims, xlim=xlims, display='filled.contour',
        col=c(NA, "purple1", "purple3", "purple4"))

    par(new=TRUE)

    #overlay
    # if(overlay != 'None' & ! is.null(overlay)){
    # if(! overlay %in% c('', 'None')){
    # if(overlay != 'None'){
    # if(length(overlay) == 1 && overlay == 'None'){
    if(is.null(overlay) || (length(overlay) == 1 && overlay == 'None')){
        NULL
    } else {
        kernel = kde(na.omit(results[results$region %in% regions &
            results$site %in% sites, c('GPP', 'ER')]))

        plot(kernel, xlab='', las=1, xaxt='n', ylab='', yaxt='n',
            ylim=ylims, xlim=xlims, display='filled.contour',
            col=c(NA, "red", "orange", "yellow"))
    }

    #peripheral stuff
    abline(0, -1, col='black', lty=3)
    axis(1, tcl=-0.2, padj=-1)
    axis(2, tcl=-0.2, hadj=0.5, las=1)
    mtext(expression(paste("GPP (g"~O[2]~"m"^"-2"~" d"^"-1"*")")),
        1, line=1.8)
    mtext(expression(paste("ER (g"~O[2]~"m"^"-2"~" d"^"-1"*")")),
        2, line=2)
}
