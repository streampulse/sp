
kdens_legend = function(is_overlay){
    par(mar = rep(0,4), oma = rep(0,4))
    plot(1,1, axes=FALSE, type='n', xlab='', ylab='', bty='o')
    legend("bottomleft", c("75%", "50%", "25%"), bty="n", bg='white',
        lty=c(1,1,1), lwd=4, col=c("gray70", "gray50", "gray30"),
        seg.len=1, box.col='transparent', horiz=TRUE, title='Overall density')

    legend('bottom', '1:1', bg='white', lty=3, bty='n')

    if(is_overlay){
        legend("bottomright", c("75%", "50%", "25%"), bty="n", bg='white',
            lty=c(1,1,1), lwd=4, col=c("red", "orange", "yellow"),
            seg.len=1, box.col='transparent', horiz=TRUE,
            title='Density of subset')
    }
}

kdens_plot = function(overlay, tmin, tmax, recompute_overall_dens=FALSE){

    par(mar=c(4,4,0,0), oma=rep(0,4))

    #get plot limits (too computationally expensive, just getting overlay info)
    if(is.null(overlay) || (length(overlay) == 1 && overlay == 'None')){
        # ylims = quantile(results$ER[doy > tmin & doy < tmax],
        #     probs=c(0.01, 0.99), na.rm=TRUE)
        # xlims = quantile(results$GPP[doy > tmin & doy < tmax],
        #     probs=c(0.01, 0.99), na.rm=TRUE)
        NULL
    } else {
        overlay = overlay[overlay != 'None']
        regionsite = sapply(overlay, strsplit, '_')
        regions = unique(sapply(regionsite, function(x) x[1]))
        sites = unique(sapply(regionsite, function(x) x[2]))
        # subset_i = results$region %in% regions & results$site %in% sites &
        #     doy > tmin & doy < tmax
        # yla = quantile(results$ER[subset_i], probs=c(0.03, 0.97), na.rm=TRUE)
        # xla = quantile(results$GPP[subset_i], probs=c(0.03, 0.97), na.rm=TRUE)
        # ylb = quantile(results$ER, probs=c(0.01, 0.99), na.rm=TRUE)
        # xlb = quantile(results$GPP, probs=c(0.01, 0.99), na.rm=TRUE)
        # ylims = range(c(yla, ylb))
        # xlims = range(c(xla, xlb))
        # if(any(is.na(c(xlims, ylims)))){
        #     plot(1, 1, axes=FALSE, ann=FALSE, type='n')
        #     text(1, 1, 'No overlay data for\nselected time range.', col='red',
        #         cex=1.5)
        #     return()
        # }
    }

    ylims = c(-15, 5)
    xlims = c(-5, 15)

    #overall plot
    if(recompute_overall_dens){
        overall_kernel = kde(na.omit(results[doy > tmin & doy < tmax,
            c('GPP','ER')]))
    }

    plot(overall_kernel, xlab='', las=1, xaxt='n', ylab='', yaxt='n',
        ylim=ylims, xlim=xlims, display='filled.contour',
        col=c(NA, "gray70", "gray50", "gray30"))

    #overlay
    if(is.null(overlay) || (length(overlay) == 1 && overlay == 'None')){
        NULL
    } else {

        results_sub = na.omit(results[results$region %in% regions &
            results$site %in% sites & doy > tmin & doy < tmax,
            c('GPP', 'ER')])

        if(nrow(results_sub) < 4){
            plot(1, 1, axes=FALSE, ann=FALSE, type='n')
            text(1, 1, 'No overlay data for\nselected site(s) and\ntime range.',
                col='red',
                cex=1.5)
            return()
        }

        site_kernel = kde(results_sub)

        par(new=TRUE)
        plot(site_kernel, xlab='', las=1, xaxt='n', ylab='', yaxt='n',
            ylim=ylims, xlim=xlims, display='filled.contour',
            col=c(NA, adjustcolor('red', alpha.f=0.5),
                adjustcolor('orange', alpha.f=0.5),
                adjustcolor('yellow', alpha.f=0.5)))
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
