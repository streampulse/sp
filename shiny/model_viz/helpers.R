processing_func = function (ts, st, en) {

    gpp = ts$GPP; gppup = ts$GPP.upper; gpplo = ts$GPP.lower
    er = ts$ER; erup = ts$ER.upper; erlo = ts$ER.lower

    ts_full = as.data.frame(ts)

    ts_full$Year = as.numeric(format(ts_full$date, "%Y"))
    ts_full$DOY = as.numeric(format(ts_full$date, "%j"))
    ts_full$NPP = ts_full$GPP + ts_full$ER

    # ts_full = ts_full[-c(1,nrow(ts_full)), -c(1,8,9,10)]
    ignore_cols = colnames(ts_full) %in% c('date','msgs.fit','warnings','errors')
    ts_full = ts_full[, -ignore_cols]
    if(sum(is.na(ts_full[c(1, nrow(ts_full)),])) >= 14){
        ts_full = ts_full[-c(1, nrow(ts_full)),]
    }
    ts_full = ts_full[ts_full$DOY > st & ts_full$DOY < en,]

    return(ts_full)
}

season_ts_func = function (ts_full, fit_daily, st, en, overlay=NULL){
# season_ts_func = function (ts_full, mod, st, en, overlay=NULL){
    # print(paste('time2_toggleA', 'time2_toggleB', 'slider_toggleA', 'slider_toggleB'))
    # print(paste(time2_toggleA, time2_toggleB, slider_toggleA, slider_toggleB))
    # ts_full = ts_full[-c(1,nrow(ts_full)),-c(1,8,9,10,11)]
    ts_full = ts_full[, colnames(ts_full) != 'Year']

    ts_full_preagg = ts_full[, !colnames(ts_full) %in% c('msgs.fit','warnings',
        'errors')]
    avg_trajectory = aggregate(ts_full_preagg, by=list(ts_full$DOY),
        FUN=mean, na.rm=TRUE)

    gpp = avg_trajectory$GPP
    gppup = avg_trajectory$GPP.upper; gpplo = avg_trajectory$GPP.lower
    er = avg_trajectory$ER
    erup = avg_trajectory$ER.upper; erlo = avg_trajectory$ER.lower
    doy = avg_trajectory$DOY

    sd_trajectory = aggregate(ts_full_preagg, by=list(ts_full$DOY),
        FUN=sd, na.rm=TRUE)

    #get bounds
    llim = min(c(gpplo, erlo), na.rm=TRUE)
    ulim = max(c(gppup, erup), na.rm=TRUE)
    maxmin_day = range(doy, na.rm=TRUE)

    # plot(avg_trajectory[, gpp_var],
    plot(doy, avg_trajectory$GPP, type="l", col="red", xlab='', las=0,
        # ylab=expression(paste("gO"[2] * " m"^"-2" * " d"^"-1")),
        ylab='', xaxs='i', yaxs='i',
        ylim=c(llim, ulim), lwd=2, xaxt='n', bty='l',
        xlim=c(max(st, maxmin_day[1]), min(en, maxmin_day[2])))
    mtext(expression(paste("g"~O[2]~"m"^"-2"~" d"^"-1")), side=2,
        line=2.5, font=2)

    #split time and DO series into NA-less chunks for plotting polygons
    ff = data.frame(doy=doy, gpplo=gpplo, gppup=gppup, erlo=erlo, erup=erup)
    # if('valid_day' %in% colnames(fit_daily)){
    #     fit_daily = fit_daily[fit_daily$valid_day,]
    # }

    if(! is.null(overlay) && overlay == 'mean daily K600'){
        # if(powell){
        #     ff$Kup = fit_daily$K600_daily_97.5pct
        #     ff$Klo = fit_daily$K600_daily_2.5pct
        # } else {
        ff = merge(ff,
            fit_daily[,c('doy', 'K600_daily_mean', 'K600_daily_97.5pct',
                'K600_daily_2.5pct')],
            by='doy', all.x=TRUE)
        colnames(ff)[colnames(ff) == 'K600_daily_97.5pct'] = 'Kup'
        colnames(ff)[colnames(ff) == 'K600_daily_2.5pct'] = 'Klo'
        # }
    }

    rl = rle(is.na(ff$gpplo))
    vv = !rl$values
    chunkfac = rep(cumsum(vv), rl$lengths)
    chunkfac[chunkfac == 0] = 1
    chunks = split(ff, chunkfac)
    noNAchunks = lapply(chunks, function(x) x[!is.na(x$gpplo),] )

    for(i in 1:length(noNAchunks)){
        polygon(x=c(noNAchunks[[i]]$doy, rev(noNAchunks[[i]]$doy)),
            y=c(noNAchunks[[i]]$gpplo, rev(noNAchunks[[i]]$gppup)),
            col=adjustcolor('red', alpha.f=0.3), border=NA)
        polygon(x=c(noNAchunks[[i]]$doy, rev(noNAchunks[[i]]$doy)),
            y=c(noNAchunks[[i]]$erlo, rev(noNAchunks[[i]]$erup)),
            col=adjustcolor('blue', alpha.f=0.3), border=NA)
    }

    lines(doy, avg_trajectory$ER, col="blue", lwd=2)
    abline(h=0, lty=3, col='gray50')

    #overlay user selected variable
    if(! is.null(overlay) && overlay == 'mean daily K600'){
        par(new=TRUE)
        llim2 = min(ff$Klo, na.rm=TRUE)
        ulim2 = max(ff$Kup, na.rm=TRUE)

        if(is.infinite(llim2) || is.infinite(ulim2)){
            llim2 = min(ff$K600_daily_mean, na.rm=TRUE)
            ulim2 = max(ff$K600_daily_mean, na.rm=TRUE)
        }

        if(is.infinite(llim2)){
            llim2 = 100
            ulim2 = 0
        }

        # plot(doy, fit_daily$K600_daily_mean,
        plot(doy, ff$K600_daily_mean, col='orange',
            type='l', xlab='', las=0, ylab='', xaxs='i', yaxs='i',
            lwd=2, xaxt='n', bty='u', yaxt='n', ylim=c(llim2, ulim2),
            xlim=c(max(st, maxmin_day[1]), min(en, maxmin_day[2])))
        axis(4)#, col.axis='orange')
        mtext(expression(paste('K600 (d'^'-1' * ')')), side=4,
            line=2.5, font=2)#, col='orange')
        for(i in 1:length(noNAchunks)){
            polygon(x=c(noNAchunks[[i]]$doy, rev(noNAchunks[[i]]$doy)),
                y=c(noNAchunks[[i]]$Klo, rev(noNAchunks[[i]]$Kup)),
                col=adjustcolor('orange', alpha.f=0.3), border=NA)
        }
        # lines(mod$data[,overlay])
    }

}

metab_legend = function(show_K600=FALSE){
    par(mar=c(0,4,0,1), oma=rep(0,4))
    plot(1,1, axes=FALSE, type='n', xlab='', ylab='', bty='o')
    if(show_K600 == FALSE){
        legend("bottomleft", ncol=2, xpd=FALSE,
            legend=c("GPP", "ER"), bty="n", lty=1,
            lwd=2, col=c("red", "blue"),
            x.intersp=c(.5,.5))
        legend('bottom', horiz=TRUE, seg.len=1,
            bty="n", lty=1, legend=c('95% CIs',''),
            col=c(adjustcolor('red', alpha.f=0.3),
                adjustcolor('blue', alpha.f=0.3)),
            lwd=6)
    } else {
        legend("bottomleft", ncol=3, xpd=FALSE,
            legend=c("GPP", "ER", 'K600'), bty="n", lty=1,
            lwd=2, col=c("red", "blue", 'orange'),
            x.intersp=c(.5,.5,.5))
        legend("bottom", ncol=3, xpd=FALSE,
            legend=c('', '', '95% CIs'), bty='n', lty=1, lwd=6,
            col=c(adjustcolor('red', alpha.f=0.3),
                adjustcolor('blue', alpha.f=0.3),
                adjustcolor('orange', alpha.f=0.3)),
            x.intersp=c(0,0,0), text.width=c(0,0,0))
    }
}

kernel_func = function(ts_full, main){
    # ts_full = ts_full[-c(1,nrow(ts_full)),-c(1,8,9,10)]

    kernel = kde(na.omit(ts_full[, c('GPP', 'ER')]))
    # k_lim = max(kernel$estimate, na.rm=TRUE)
    k_lim = max(abs(c(min(ts_full$ER, na.rm=TRUE),
        max(ts_full$GPP, na.rm=TRUE))))
    plot(kernel, xlab='', las=1, xaxt='n', ylab='', yaxt='n',
        ylim=c(-k_lim, 0), xlim=c(0, k_lim), display='filled.contour',
        # ylim=c(-k_lim, k_lim), xlim=c(-k_lim, k_lim), display='filled.contour',
        col=c(NA, "purple1", "purple3", "purple4"))
    axis(1, tcl=-0.2, padj=-1)
    axis(2, tcl=-0.2, hadj=0.5, las=1)
    mtext(expression(paste("GPP (g"~O[2]~"m"^"-2"~" d"^"-1"*")")),
        1, line=1.8)
    mtext(expression(paste("ER (g"~O[2]~"m"^"-2"~" d"^"-1"*")")),
        2, line=2)
    # mtext(main, 3, line=-2)
    abline(0, -1, col='black', lty=3)
    # legend("bottomright", c("75%", "50%", "25%"), bty="o", bg='white',
    #     lty=c(1,1,1), lwd=4, col=c("purple1", "purple3", "purple4"),
    #     seg.len=1, box.col='transparent')#, xpd=TRUE, inset=c(-0.3,0))
}

kernel_legend = function(){
    par(mar = rep(0,4), oma = rep(0,4))
    plot(1,1, axes=FALSE, type='n', xlab='', ylab='', bty='o')
    legend("bottomright", c("75%", "50%", "25%"), bty="o", bg='white',
        lty=c(1,1,1), lwd=4, col=c("purple1", "purple3", "purple4"),
        seg.len=1, box.col='transparent', horiz=TRUE)
}

O2_plot = function(mod_out, st, en, brush, click, overlay='None',
    xformat='DOY'){
    # st=0; en=366
    # brush = list(xmin=1460617508, xmax=1464058124, ymin=8.816155, ymax=14.45195)

    #convert POSIX time to DOY and UNIX time
    DOY = as.numeric(gsub('^0+', '', strftime(mod_out$data$solar.time,
        format="%j")))
    ustamp = as.numeric(as.POSIXct(mod_out$data$solar.time, tz='UTC'))

    #replace initial DOYs of 365 or 366 (solar date in previous calendar year) with 1
    if(DOY[1] %in% 365:366){
        DOY[DOY %in% 365:366 & 1:length(DOY) < length(DOY)/2] = 1
    }

    #get bounds
    xmin_ind = match(st, DOY)
    if(is.na(xmin_ind)) xmin_ind = 1
    xmin = ustamp[xmin_ind]

    xmax_ind = length(DOY) - match(en, rev(DOY)) + 1
    if(is.na(xmax_ind)) xmax_ind = nrow(mod_out$data)
    xmax = ustamp[xmax_ind]

    DOmod_exists = 'DO.mod' %in% colnames(mod_out$data)
    if(DOmod_exists){
        DOcols = c('DO.obs', 'DO.mod')
    } else {
        DOcols = 'DO.obs'
    }

    #overlay additional series if selected
    if(overlay != 'None'){
        cleaned_varnames = sapply(varmap, function(x) x[[1]])
        overlay = names(varmap)[which(cleaned_varnames == overlay)]
        slice = mod_out$data[xmin_ind:xmax_ind, c(DOcols, overlay)]
    } else {
        slice = mod_out$data[xmin_ind:xmax_ind, DOcols, drop=FALSE]
    }

    if(DOmod_exists){
        yrng = range(c(slice$DO.obs, slice$DO.mod), na.rm=TRUE)
    } else {
        yrng = range(slice$DO.obs, na.rm=TRUE)
    }

    #window, series, axis labels
    plot(ustamp, mod_out$data$DO.obs, xaxt='n', las=0,
        type='n', xlab='', ylab='', bty='l', ylim=c(yrng[1], yrng[2]),
        xaxs='i', yaxs='i', xlim=c(xmin, xmax))

    #split time and DO series into NA-less chunks for plotting polygons
    if(DOmod_exists){
        ff = data.frame(ustamp=ustamp, DO=mod_out$data$DO.mod,
            zero=rep(0, length(mod_out$data$DO.mod)))
        rl = rle(is.na(ff$DO))
        vv = !rl$values
        chunkfac = rep(cumsum(vv), rl$lengths)
        chunkfac[chunkfac == 0] = 1
        chunks = split(ff, chunkfac)
        noNAchunks = lapply(chunks, function(x) x[!is.na(x$DO),] )

        for(i in 1:length(noNAchunks)){
            polygon(x=c(noNAchunks[[i]]$ustamp, rev(noNAchunks[[i]]$ustamp)),
                y=c(noNAchunks[[i]]$DO, rep(0, nrow(noNAchunks[[i]]))),
                col='gray75', border='gray75')
        }
    }

    mtext(expression(paste('DO (mgL'^'-1' * ')')), 2, font=1, line=2.5)
    lines(ustamp, mod_out$data$DO.obs, col='cyan4')

    #get seq of 10 UNIX timestamps and use corresponding DOYs/dates as ticks
    tcs = seq(xmin, xmax, length.out=10)
    near_ind = findInterval(tcs, ustamp)

    if(xformat == 'DOY'){
        axis(1, ustamp[near_ind], DOY[near_ind], tcl=-0.2, padj=-1)
        mtext('DOY', 1, font=1, line=1.5)
    } else { #xformat == 'Date'
        date = as.Date(gsub('^0+', '', strftime(mod_out$data$solar.time,
            format="%Y-%m-%d")))
        if(DOY[1] %in% 365:366){
            date[DOY %in% 365:366 & 1:length(DOY) < length(DOY)/2] = NA
        }
        axis(1, ustamp[near_ind], date[near_ind], tcl=-0.2, padj=-1)
        mtext('Date', 1, font=1, line=1.5)
    }

    # overlay user selected variable
    if(overlay != 'None'){
        par(new=TRUE)
        yrng2 = range(slice[,overlay], na.rm=TRUE)
        plot(ustamp, mod_out$data[,overlay], xaxt='n', las=0, yaxt='n',
            type='l', xlab='', ylab='', bty='u', ylim=c(yrng2[1], yrng2[2]),
            xaxs='i', yaxs='i', xlim=c(xmin, xmax), col='coral4')
        axis(4)
        mtext(varmap[[overlay]][[2]], side=4, line=2.5)
    }

    #highlight brushed points
    hl_log_ind = which(mod_out$data$DO.mod < brush$ymax &
            mod_out$data$DO.mod > brush$ymin &
            ustamp < brush$xmax & ustamp > brush$xmin)
    hl_x = ustamp[hl_log_ind]
    hl_y = mod_out$data$DO.mod[hl_log_ind]
    points(hl_x, hl_y, col='goldenrod1', cex=0.3, pch=20)

}

O2_legend = function(overlay, powell){
    par(mar=c(0,4,0,1), oma=rep(0,4))
    plot(1,1, axes=FALSE, type='n', xlab='', ylab='', bty='o')
    if(overlay == 'None'){
        predtxt = ifelse(powell, 'Pred (unpublished)', 'Pred')
        legend(x='bottomleft', legend=c(predtxt, 'Obs'), bg='white',
            cex=0.8, col=c('gray75', 'cyan4'), lty=1, bty='o', horiz=TRUE,
            lwd=c(6,2), box.col='transparent')
    } else {
        cleaned_varnames = sapply(varmap, function(x) x[[1]])
        overlay = names(varmap)[which(cleaned_varnames == overlay)]
        predtxt = ifelse(powell, 'Pred DO (unpublished)', 'Pred DO')
        legend(x='bottomleft', legend=c(predtxt, 'Obs DO',
            varmap[[overlay]][[1]]),
            bg='white', cex=0.8, col=c('gray75', 'cyan4', 'coral4'),
            lty=1, bty='o', horiz=TRUE,
            lwd=c(6,2,2), box.col='transparent')
    }
}

KvER_plot = function(mod_out, slice, click=NULL){

    mod = try(lm(slice$ER_daily_mean ~ slice$K600_daily_mean),
              silent = TRUE)

    if(! inherits(mod, 'try-error')){
        R2 = sprintf('%1.2f', summary(mod)$adj.r.squared)
    } else {
        R2 = 'NA'
    }

    plot(slice$K600_daily_mean, slice$ER_daily_mean,
        col='darkgreen', ylab='', xlab='Daily mean K600',
        bty='l', font.lab=1, cex.axis=0.8, las=1)
    mtext(expression(paste("Daily mean ER (g"~O[2]~"m"^"-2"*")")), side=2, line=2.5)
    mtext(bquote('Adj.' ~ R^2 * ':' ~ .(R2)), side=3, line=0, adj=1,
        cex=0.8, col='gray50')
    if(! inherits(mod, 'try-error') && ! any(is.na(mod$coefficients))){
        abline(mod, lty=2, col='gray50', lwd=2)
    }

    #highlight point and display date on click
    if(! is.null(click) && ! is.null(click$x)){
        xmax = max(slice$K600_daily_mean, na.rm=TRUE)
        xmin = min(slice$K600_daily_mean, na.rm=TRUE)
        ymax = max(slice$ER_daily_mean, na.rm=TRUE)
        ymin = min(slice$ER_daily_mean, na.rm=TRUE)
        xrng = xmax - xmin
        yrng = ymax - ymin

        clickTol = 0.06
        x_clickTol_scale = clickTol / xrng
        y_clickTol_scale = clickTol / yrng

        click_ind = which(slice$ER_daily_mean < click$y + y_clickTol_scale * yrng &
                slice$ER_daily_mean > click$y - y_clickTol_scale * yrng &
                slice$K600_daily_mean < click$x + x_clickTol_scale * xrng &
                slice$K600_daily_mean > click$x - x_clickTol_scale * xrng)[1]
        click_x = slice$K600_daily_mean[click_ind]
        click_y = slice$ER_daily_mean[click_ind]
        points(click_x, click_y, col='goldenrod1', pch=19, cex=2)
        x_prop = rescale(click_x, c(0, 1), c(xmin, xmax))
        if(! is.na(x_prop) && x_prop > 0.5){
            text(click_x, click_y, '-', pos=2, font=2, col='white', cex=9)
            text(click_x, click_y, '- ', pos=2, font=2, col='white', cex=9)
            text(click_x, click_y, paste0(slice$date[click_ind], ' '), pos=2, font=2)
        } else {
            text(click_x, click_y, '-', pos=4, font=2, col='white', cex=9)
            text(click_x, click_y, ' -', pos=4, font=2, col='white', cex=9)
            text(click_x, click_y, '--', pos=4, font=2, col='white', cex=9)
            text(click_x, click_y, paste0(' ', slice$date[click_ind]), pos=4, font=2)
        }
    }
}

KvGPP_plot = function(mod_out, slice, click=NULL){

    plot(slice$K600_daily_mean, slice$GPP_daily_mean,
        col='darkblue', ylab='', xlab='Daily mean K600',
        bty='l', font.lab=1, cex.axis=0.8, las=1)
    mtext(expression(paste("Daily mean GPP (g"~O[2]~"m"^"-2"*")")), side=2, line=2.5)

    #highlight point and display date on click
    if(! is.null(click) && ! is.null(click$x)){

        xmax = max(slice$K600_daily_mean, na.rm=TRUE)
        xmin = min(slice$K600_daily_mean, na.rm=TRUE)
        ymax = max(slice$GPP_daily_mean, na.rm=TRUE)
        ymin = min(slice$GPP_daily_mean, na.rm=TRUE)
        xrng = xmax - xmin
        yrng = ymax - ymin

        clickTol = 0.06
        x_clickTol_scale = clickTol / xrng
        y_clickTol_scale = clickTol / yrng

        click_ind = which(slice$GPP_daily_mean < click$y + y_clickTol_scale * yrng &
                slice$GPP_daily_mean > click$y - y_clickTol_scale * yrng &
                slice$K600_daily_mean < click$x + x_clickTol_scale * xrng &
                slice$K600_daily_mean > click$x - x_clickTol_scale * xrng)[1]
        click_x = slice$K600_daily_mean[click_ind]
        click_y = slice$GPP_daily_mean[click_ind]
        points(click_x, click_y, col='goldenrod1', pch=19, cex=2)
        x_prop = rescale(click_x, c(0, 1), c(xmin, xmax))
        if(! is.na(x_prop) && x_prop > 0.5){
            text(click_x, click_y, '-', pos=2, font=2, col='white', cex=9)
            text(click_x, click_y, '- ', pos=2, font=2, col='white', cex=9)
            text(click_x, click_y, paste0(slice$date[click_ind], ' '), pos=2, font=2)
        } else {
            text(click_x, click_y, '-', pos=4, font=2, col='white', cex=9)
            text(click_x, click_y, ' -', pos=4, font=2, col='white', cex=9)
            text(click_x, click_y, paste0(' ', slice$date[click_ind]), pos=4, font=2)
        }
    }
}

KvQ_plot = function(mod_out, slicex, slicey, powell, click=NULL){

    # if(! powell){
    #     nodes = mod_out$fit$KQ_binned$lnK600_lnQ_nodes_mean
    # }

    colnames(slicex)[colnames(slicex) == 'discharge'] = 'discharge.daily'
    slicexy = merge(slicey, slicex[,c('date','discharge.daily')],
        by='date', all=TRUE)
    log_Q = log(slicexy$discharge.daily)

    if(all(is.na(log_Q))){
        plot(1, 1, xlab='Log daily mean Q (cms)', ylab='Daily mean K600',
             bty='l', font.lab=1, cex.axis=0.8, las=1, type='n')
        text(1, 1, labels='K600 fixed', adj=0.5)
        return()
    }

    # if(! powell){
    #     xminplot = min(c(log_Q, nodes), na.rm=TRUE)
    #     xmaxplot = max(c(log_Q, nodes), na.rm=TRUE)
    # } else {
        xminplot = min(log_Q, na.rm=TRUE)
        xmaxplot = max(log_Q, na.rm=TRUE)
    # }

    KQmod = lm(slicexy$K600_daily_mean ~ log_Q)
    R2 = sprintf('%1.2f', summary(KQmod)$adj.r.squared)
    plot(log_Q, slicexy$K600_daily_mean, xlim=c(xminplot, xmaxplot),
        col='purple4', xlab='Log daily mean Q (cms)', ylab='Daily mean K600',
        bty='l', font.lab=1, cex.axis=0.8, las=1)

    #if(! powell){
    #    abline(v=nodes, lty=2, col='darkred')
    #    mtext('log Q node centers', side=3, line=0, adj=1, cex=0.8, col='darkred')
    #} else {
    #    mtext('log Q node centers (unavail.)', side=3, line=0, adj=1, cex=0.8,
    #        col='darkred')
    #}

    mtext(bquote('Adj.' ~ R^2 * ':' ~ .(R2)), side=3, line=0, adj=0,
        cex=0.8, col='gray50')
    abline(KQmod, lty=2, col='gray50', lwd=2)
    # legend('topright', legend='log Q node centers', bty='n', lty=2, col='gray')

    # slicexy = slicexy[! is.na(slicexy$discharge.daily),]

    #highlight point and display date on click
    if(! is.null(click) && ! is.null(click$x)){
        xmax = max(log_Q, na.rm=TRUE)
        xmin = min(log_Q, na.rm=TRUE)
        ymax = max(slicey$K600_daily_mean, na.rm=TRUE)
        ymin = min(slicey$K600_daily_mean, na.rm=TRUE)
        xrng = xmax - xmin
        yrng = ymax - ymin

        clickTol = 0.06
        x_clickTol_scale = clickTol / xrng
        y_clickTol_scale = clickTol / yrng

        click_ind_x = which(log_Q < click$x + x_clickTol_scale * xrng & log_Q >
            click$x - x_clickTol_scale * xrng)
        click_ind_y = which(slicey$K600_daily_mean < click$y + y_clickTol_scale * yrng &
                slicey$K600_daily_mean > click$y - y_clickTol_scale * yrng)
        click_ind = intersect(click_ind_x, click_ind_y)[1]

        click_x = log_Q[click_ind]
        click_y = slicey$K600_daily_mean[click_ind]

        points(click_x, click_y, col='goldenrod1', pch=19, cex=2)
        x_prop = rescale(click_x, c(0, 1), c(xmin, xmax))
        if(! is.na(x_prop) && x_prop > 0.5){
            text(click_x, click_y, '-', pos=2, font=2, col='white', cex=9)
            text(click_x, click_y, '- ', pos=2, font=2, col='white', cex=9)
            text(click_x, click_y, paste0(slicey$date[click_ind], ' '),
                pos=2, font=2)
        } else {
            text(click_x, click_y, '-', pos=4, font=2, col='white', cex=9)
            text(click_x, click_y, ' -', pos=4, font=2, col='white', cex=9)
            text(click_x, click_y, paste0(' ', slicey$date[click_ind]),
                pos=4, font=2)
        }
    }
}

QvKres_plot = function(mod_out, slicex, slicey, click=NULL){

    colnames(slicex)[colnames(slicex) == 'discharge'] = 'discharge.daily'
    slicexy = merge(slicey, slicex[,c('date','discharge.daily')],
        by='date', all.x=TRUE)
    log_Q = log(slicexy$discharge.daily)

    if(all(is.na(log_Q))){
        plot(1, 1, xlab='Log daily mean Q (cms)', ylab='Daily mean K600 residuals',
             bty='l', font.lab=1, cex.axis=0.8, las=1, type='n')
        text(1, 1, labels='K600 fixed', adj=0.5)
        return()
    }

    #get K residuals (based on K-Q linear relationship)
    KQmod = lm(slicexy$K600_daily_mean ~ log_Q, na.action=na.exclude)
    KQrelat = fitted(KQmod)
    # if(length(KQrelat) != length(slicey$K600_daily_mean)){
    #     if(is.na(slicey$K600_daily_mean[1])){
    #         KQrelat = c(NA, KQrelat)
    #     } else {
    #         KQrelat = c(KQrelat, NA)
    #     }
    # }
    # if(length(KQrelat) != length(slicey$K600_daily_mean)){
    #     KQrelat = c(KQrelat, NA)
    # }

    resid = slicexy$K600_daily_mean - KQrelat

    plot(log_Q, resid,
        col='purple4', xlab='Log daily mean Q (cms)',
        ylab='Daily mean K600 residuals*',
        bty='l', font.lab=1, cex.axis=0.8, las=1)

    # slicexy = slicexy[! is.na(slicexy$discharge.daily),]

    #highlight point and display date on click
    if(! is.null(click) && ! is.null(click$x)){

        xmax = max(log_Q, na.rm=TRUE)
        xmin = min(log_Q, na.rm=TRUE)
        ymax = max(resid, na.rm=TRUE)
        ymin = min(resid, na.rm=TRUE)
        xrng = xmax - xmin
        yrng = ymax - ymin

        # rm(list=c('click','log_Q','resid','xmax','xmin','ymax','ymin','xrng',
        #     'yrng','x_clickTol_scale','y_clickTol_scale','click_ind_x',
        #     'click_ind_y','click_x','click_y','x_prop'))
        clickTol = 0.06
        x_clickTol_scale = clickTol / xrng
        y_clickTol_scale = clickTol / yrng

        click_ind_x = which(log_Q < click$x + x_clickTol_scale * xrng & log_Q >
            click$x - x_clickTol_scale * xrng)
        click_ind_y = which(resid < click$y + y_clickTol_scale * yrng &
            resid > click$y - y_clickTol_scale * yrng)
        click_ind = intersect(click_ind_x, click_ind_y)[1]

        click_x = log_Q[click_ind]
        click_y = resid[click_ind]

        points(click_x, click_y, col='goldenrod1', pch=19, cex=2)
        x_prop = rescale(click_x, c(0, 1), c(xmin, xmax))
        if(! is.na(x_prop) && x_prop > 0.5){
            text(click_x, click_y, '-', pos=2, font=2, col='white', cex=9)
            text(click_x, click_y, '- ', pos=2, font=2, col='white', cex=9)
            text(click_x, click_y, paste0(slicexy$date[click_ind], ' '),
                pos=2, font=2)
        } else {
            text(click_x, click_y, '-', pos=4, font=2, col='white', cex=9)
            text(click_x, click_y, ' -', pos=4, font=2, col='white', cex=9)
            text(click_x, click_y, paste0(' ', slicexy$date[click_ind]),
                pos=4, font=2)
        }
    }
}

# cumulative_func = function (ts_full, st, en){
#
#     na_rm = na.omit(ts_full)
#     na_rm$csum_gpp = ave(na_rm$GPP, na_rm$Year, FUN=cumsum)
#     na_rm$csum_er = ave(na_rm$ER, na_rm$Year, FUN=cumsum)
#     na_rm$csum_npp = ave(na_rm$NPP, na_rm$Year, FUN=cumsum)
#
#     lim = range(na_rm[, c('csum_gpp', 'csum_er', 'csum_npp')], na.rm=TRUE)
#
#     plot(na_rm$DOY, na_rm$csum_gpp, pch=20, xlab='', bty='l',
#         cex=1, type='p', las=1, ylim=c(lim[1], lim[2]),
#         xaxt='n', yaxt='n', xlim=c(st, en), ylab='', col='red')
#     points(na_rm$DOY, na_rm$csum_er, pch=20, cex=1, col='blue')
#     points(na_rm$DOY, na_rm$csum_npp, pch=20, cex=1, col='purple')
#     maxcumul = na_rm[nrow(na_rm), c('csum_gpp', 'csum_er', 'csum_npp')]
#     text(rep(max(na_rm$DOY), 3), maxcumul, labels=round(maxcumul),
#         pos=2, cex=0.8)
#
#     mtext(expression(paste("Cumulative O"[2] * " (gm"^"-2" * " d"^"-1" * ')')),
#         2, line=2.3)
#
#     axis(2, tcl=-0.2, hadj=0.7, las=1, cex.axis=0.7)
#     month_labs = substr(month.abb, 0, 1)
#     axis(1, seq(1, 365, length.out=12), month_labs, tcl=-0.2, padj=-1,
#         cex.axis=0.6)
#     abline(h=0, col="grey50", lty=3)
# }
#
# cumul_legend = function(){
#     par(mar = rep(0,4), oma = rep(0,4))
#     plot(1,1, axes=FALSE, type='n', xlab='', ylab='', bty='o')
#     legend("bottomright", legend=c('GPP', 'ER', 'NEP'), seg.len=1,
#         col=c('red', 'blue', 'purple'), lty=1, lwd=3, bty='n', xpd=FALSE,
#         horiz=TRUE)
# }
