processing_func = function (ts, st, en) {
    gpp = ts$GPP; gppup = ts$GPP.upper; gpplo = ts$GPP.lower
    er = ts$ER; erup = ts$ER.upper; erlo = ts$ER.lower
    # ts[!is.na(gpp) & gpp < 0 | !is.na(gpp) & gpp > 100, 'GPP'] = NA
    # ts[!is.na(er) & er > 0, 'ER'] = NA
    # if('tbl' %in% class(ts$date)){

    # full_dates = as.data.frame(ts$date)
    # colnames(full_dates) = 'Date'

    # colnames(ts)[which(colnames(ts) == 'date')] = 'Date'
    ts_full = as.data.frame(ts)
    # } else {
    #     ts_date = ts$date
    #     ts$Date = format(ts_date, "%Y-%m-%d")
    #     full_dates = setNames(data.frame(
    #         seq(from = as.Date(paste(min(format(ts$date, "%Y")),
    #             "-01-01", sep = "")),
    #             to = as.Date(paste(max(format(ts[,
    #                 date_var], "%Y")), "-12-31", sep = "")), by = 1)), "Date")
    # }

    # ts_full = merge(full_dates, ts, by = c("Date"), all = TRUE)
    ts_full$Year = as.numeric(format(ts_full$date, "%Y"))
    ts_full$DOY = as.numeric(format(ts_full$date, "%j"))
    ts_full$NPP = ts_full$GPP + ts_full$ER

    ts_full = ts_full[-c(1,nrow(ts_full)), -c(1,8,9,10)]
    ts_full = ts_full[ts_full$DOY > st & ts_full$DOY < en,]

    return(ts_full)
}

season_ts_func = function (ts_full, suppress_NEP=FALSE, st, en){
    # print(paste('time2_toggleA', 'time2_toggleB', 'slider_toggleA', 'slider_toggleB'))
    # print(paste(time2_toggleA, time2_toggleB, slider_toggleA, slider_toggleB))
    # ts_full = ts_full[-c(1,nrow(ts_full)),-c(1,8,9,10,11)]
    ts_full = ts_full[, colnames(ts_full) != 'Year']

    avg_trajectory = aggregate(ts_full, by=list(ts_full$DOY),
        FUN=mean, na.rm=TRUE)

    gpp = avg_trajectory$GPP
    gppup = avg_trajectory$GPP.upper; gpplo = avg_trajectory$GPP.lower
    er = avg_trajectory$ER
    erup = avg_trajectory$ER.upper; erlo = avg_trajectory$ER.lower
    doy = avg_trajectory$DOY

    sd_trajectory = aggregate(ts_full, by=list(ts_full$DOY),
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
    mtext(expression(paste("O"[2] * " m"^"-2" * " d"^"-1" ~ '(g)')), side=2,
        line=2.5, font=2)

    #split time and DO series into NA-less chunks for plotting polygons
    ff = data.frame(doy=doy, gpplo=gpplo, gppup=gppup, erlo=erlo, erup=erup)
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
    # if(suppress_NEP){
    #     # plot(1,1, col=adjustcolor('red',alpha.f=0.2))
    #     # legend("bottomleft", ncol=2, xpd=FALSE,
    #     #     legend=c("GPP", "ER"), bty="n", lty=1,
    #     #     lwd=2, col=c("red", "blue"),
    #     #     x.intersp=c(.5,.5))#, inset=c(0, -0.13), text.width=.05)
    #     # legend('bottomright', horiz=TRUE, seg.len=1,
    #     #     bty="n", lty=1, title='95% CIs', legend=c('',''),
    #     #     col=c(adjustcolor('red', alpha.f=0.3),
    #     #         adjustcolor('blue', alpha.f=0.3)),
    #     #     lwd=6)
    #     # legend('bottomright', ncol=2, xpd=FALSE, #inset=c(0.1, 0),#-0.13),
    #     #     bty="n", lty=1, title='95% CIs', legend=c('',''),#'95% CIs'),
    #     #     col=c(adjustcolor('red', alpha.f=0.3),
    #     #         adjustcolor('blue', alpha.f=0.3)),
    #     #     x.intersp=c(-.1,.5), text.width=.05, lwd=6, xjust=0)
    #
    # } else {
    #     lines(avg_trajectory$DOY, avg_trajectory$NPP, col="purple", lwd=2)
    #     # plot(1,1, col=adjustcolor('red',alpha.f=0.2))
    #     legend("bottomleft", ncol=3, xpd=FALSE,
    #     # legend("topleft", ncol=5, xpd=TRUE,
    #         c("GPP", "NEP", "ER"), bty="n", lty=1,
    #         # c("GPP", "NEP", "ER", '', '95CI'), bty="n", lty=1,
    #         lwd=2, col=c("red", "purple", "blue"))#, inset=c(0, -0.13))
    #             # adjustcolor('red', alpha.f=0.3),
    #             # adjustcolor('steelblue', alpha.f=0.3)),
    #     # x.intersp=c(.5,.5,.5,.3,1.3), text.width=.05)
    # }
    # month_labs = month.abb
    # month_labs[seq(2, 12, 2)] = ''
    # axis(1, seq(1, 365, length.out=12), month_labs)
}

metab_legend = function(){
    par(mar=c(0,4,0,1), oma=rep(0,4))
    plot(1,1, axes=FALSE, type='n', xlab='', ylab='', bty='o')
    legend("bottomleft", ncol=2, xpd=FALSE,
        legend=c("GPP", "ER"), bty="n", lty=1,
        lwd=2, col=c("red", "blue"),
        x.intersp=c(.5,.5))
    legend('bottomright', horiz=TRUE, seg.len=1,
        bty="n", lty=1, legend=c('95% CIs',''),
        col=c(adjustcolor('red', alpha.f=0.3),
            adjustcolor('blue', alpha.f=0.3)),
        lwd=6)
}

cumulative_func = function (ts_full, st, en){

    # ts_full = ts_full[-c(1,nrow(ts_full)),-c(1,8,9,10)]
    na_rm = na.omit(ts_full)
    na_rm$csum_gpp = ave(na_rm$GPP, na_rm$Year, FUN=cumsum)
    na_rm$csum_er = ave(na_rm$ER, na_rm$Year, FUN=cumsum)
    na_rm$csum_npp = ave(na_rm$NPP, na_rm$Year, FUN=cumsum)

    lim = range(na_rm[, c('csum_gpp', 'csum_er', 'csum_npp')], na.rm=TRUE)
    # lim_gpp = range(na_rm$csum_gpp, na.rm=TRUE)
    # lim_er = range(na_rm$csum_er, na.rm=TRUE)
    # lim_npp = range(na_rm$csum_npp, na.rm=TRUE)

    # lim_gpp = max(abs(na_rm[, c("csum_gpp", "csum_er")]))
    # pal = rev(brewer.pal(7, "Spectral"))
    # cols = setNames(data.frame(unique(na_rm$Year), pal[1:length(unique(na_rm[,
    #     "Year"]))]), c("Year", "color"))
    # csum_merge = merge(na_rm, cols, by="Year", type="left")

    plot(na_rm$DOY, na_rm$csum_gpp, pch=20, xlab='', bty='l',
        # cex=1.5, col=paste(csum_merge$color), type='p', las=1,
        cex=1, type='p', las=1, ylim=c(lim[1], lim[2]),
        xaxt='n', yaxt='n', xlim=c(st, en), ylab='', col='red')
        # col=adjustcolor('red', alpha.f=0.4))
    # legend("topleft", paste(c(cols$Year)), lwd=c(1, 1),
    #     col=paste(cols$color), cex=0.9)
    points(na_rm$DOY, na_rm$csum_er, pch=20, cex=1, col='blue')
        # col=adjustcolor('blue', alpha.f=0.4))
        # type='p', las=1,
        # ylim=c(lim_er[1], lim_er[2]), xaxt="n", xlim=c(st, en), ylab="Cumulative ER")
    points(na_rm$DOY, na_rm$csum_npp, pch=20, cex=1, col='purple')
        # col=adjustcolor('purple', alpha.f=0.4))
        # las=1, ylim=c(lim_npp[1], lim_npp[2]),
        # ylab="Cumulative NEP", xlim=c(st, en), xlab='', type='p', xaxt='n')

    # legend("top", legend=c('GPP', 'ER', 'NEP'), seg.len=1, inset=c(0,-0.0),
    #     col=c('red', 'blue', 'purple'), lty=1, lwd=3, bty='n', xpd=TRUE,
    #     horiz=TRUE)

    # mtext('Time', 1, line=1.8)
    mtext(expression(paste("Cumulative O"[2] * " m"^"-2" * " d"^"-1" ~ '(g)')),
        2, line=2.3)

    axis(2, tcl=-0.2, hadj=0.7, las=1, cex.axis=0.7)
    month_labs = substr(month.abb, 0, 1)
    # month_labs[seq(2, 12, 2)] = ''
    axis(1, seq(1, 365, length.out=12), month_labs, tcl=-0.2, padj=-1,
        cex.axis=0.6)
    abline(h=0, col="grey50", lty=3)
}

cumul_legend = function(){
    par(mar = rep(0,4), oma = rep(0,4))
    plot(1,1, axes=FALSE, type='n', xlab='', ylab='', bty='o')
    legend("bottomright", legend=c('GPP', 'ER', 'NEP'), seg.len=1,
        col=c('red', 'blue', 'purple'), lty=1, lwd=3, bty='n', xpd=FALSE,
        horiz=TRUE)
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
    mtext(expression(paste("GPP (gO"[2] * " m"^"-2" * " d"^"-1" * ")")),
        1, line=1.8)
    mtext(expression(paste("ER (gO"[2] * " m"^"-2" * " d"^"-1" * ")")),
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

O2_plot = function(mod_out, st, en, brush){
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

    slice = mod_out$data[xmin_ind:xmax_ind, c('DO.obs', 'DO.mod')]#, 'solar.time')]
    yrng = range(c(slice$DO.obs, slice$DO.mod), na.rm=TRUE)

    #window, series, axis labels
    plot(ustamp, mod_out$data$DO.obs, xaxt='n', las=0,
        type='n', xlab='', ylab='', bty='l', ylim=c(yrng[1], yrng[2]),
        xaxs='i', yaxs='i', xlim=c(xmin, xmax))

    #split time and DO series into NA-less chunks for plotting polygons
    ff = data.frame(ustamp=ustamp, DO=mod_out$data$DO.obs,
        zero=rep(0, length(mod_out$data$DO.obs)))
    rl = rle(is.na(ff$DO))
    vv = !rl$values
    chunkfac = rep(cumsum(vv), rl$lengths)
    chunkfac[chunkfac == 0] = 1
    chunks = split(ff, chunkfac)
    noNAchunks = lapply(chunks, function(x) x[!is.na(x$DO),] )

    for(i in 1:length(noNAchunks)){
        polygon(x=c(noNAchunks[[i]]$ustamp, rev(noNAchunks[[i]]$ustamp)),
            y=c(noNAchunks[[i]]$DO, rep(0, nrow(noNAchunks[[i]]))),
            col='gray70', border='gray70')
    }

    mtext('DOY', 1, font=1, line=1.5)
    mtext('DO (mg/L)', 2, font=1, line=3)
    # lines(mod_out$data$solar.time, mod_out$data$DO.mod,
    lines(ustamp, mod_out$data$DO.mod,
        col='royalblue4')
    # legend(x='bottomleft', legend=c('Obs', 'Pred'), bg='white',
    #     cex=0.8, col=c('gray70', 'royalblue4'), lty=1, bty='o', horiz=TRUE,
    #     lwd=c(6,1), box.col='transparent')#, inset=c(0,-0.0), xpd=TRUE)

    #get seq of 10 UNIX timestamps and use their corresponding DOYs as ticks
    tcs = seq(xmin, xmax, length.out=10)
    near_ind = findInterval(tcs, ustamp)
    axis(1, ustamp[near_ind], DOY[near_ind], tcl=-0.2, padj=-1)

    #highlight brushed points
    hl_log_ind = which(mod_out$data$DO.mod < brush$ymax &
            mod_out$data$DO.mod > brush$ymin &
            ustamp < brush$xmax & ustamp > brush$xmin)
    hl_x = ustamp[hl_log_ind]
    hl_y = mod_out$data$DO.mod[hl_log_ind]
    points(hl_x, hl_y, col='goldenrod1', cex=0.3, pch=20)

}

O2_legend = function(){
    par(mar=c(0,4,0,1), oma=rep(0,4))
    plot(1,1, axes=FALSE, type='n', xlab='', ylab='', bty='o')
    legend(x='bottomleft', legend=c('Obs', 'Pred'), bg='white',
        cex=0.8, col=c('gray70', 'royalblue4'), lty=1, bty='o', horiz=TRUE,
        lwd=c(6,1), box.col='transparent')
}

KvQvER_plot = function(mod_out){
    par(mfrow=c(1,2))
    mod = lm(mod_out$fit$daily$ER_mean ~
            mod_out$fit$daily$K600_daily_mean)
    R2 = sprintf('%1.2f', summary(mod)$adj.r.squared)
    plot(mod_out$fit$daily$K600_daily_mean, mod_out$fit$daily$ER_mean,
        col='darkgreen', ylab='', xlab='Daily mean K600',
        bty='l', font.lab=1, cex.axis=0.8, las=1)
    mtext(expression(paste("Daily mean ER (g O"[2] * " m"^"-2" ~ ")")), side=2,
        line=2.5)
    mtext(bquote('Adj.' ~ R^2 * ':' ~ .(R2)), side=3, line=0, adj=1,
        cex=0.8, col='gray50')
    abline(mod, lty=2, col='gray50', lwd=2)
    plot(log(mod_out$data_daily$discharge.daily),
        mod_out$fit$daily$K600_daily_mean,
        col='purple4', xlab='Daily mean Q (ln cms)', ylab='Daily mean K600',
        bty='l', font.lab=1, cex.axis=0.8, las=1)
}

