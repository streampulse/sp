
determine_sample_interval = function(d){

    intervals = int_diff(d$DateTime_UTC) %>%
        time_length(unit='minute') %>%
        table()
    primary_interval_m = as.numeric(names(intervals)[which.max(intervals)])

    return(primary_interval_m)
}

populate_missing_rows = function(d, samp_int){
    #samp_int is the sample interval in minutes

    daterange = range(d$DateTime_UTC, na.rm=TRUE)
    dt_filled = data.frame(DateTime_UTC=seq(daterange[1], daterange[2],
        by=paste(samp_int, 'min')))
    d = right_join(d, dt_filled, by='DateTime_UTC')

    if('upload_id' %in% colnames(d)){
        d = mutate(d, upload_id=imputeTS::na_locf(upload_id))
    }

    return(d)
}

lin_interp_gaps = function(d, na_thresh=1, samp_int=NULL, gap_thresh=Inf){
    #if > na_thresh proportion of a series is NA, don't interpolate
    #samp_int is the sample interval in minutes
    #gaps larger than gap_thresh minutes will not be filled

    if(! is.null(samp_int) && (length(samp_int) != 1 || ! is.numeric(samp_int))){
        stop('samp_int must be a numeric of length 1.')
    }

    if(is.null(samp_int) && gap_thresh < Inf){
        warning('samp_int is NULL, so ignoring gap_thresh.')
    }

    gap_thresh_n = gap_thresh / samp_int

    if (length(gap_thresh_n) == 0) {
        gap_thresh_n = Inf
    } else if(gap_thresh_n <= 0){
        stop(paste('Cannot interpolate gaps of length', gap_thresh, '/',
            samp_int, '=', gap_thresh_n))
    }

    d = as.data.frame(apply(d, 2,
        function(x){
            if(sum(is.na(x)) / length(x) >= na_thresh) return(x)
            imputeTS::na_interpolation(x, option='linear', maxgap=gap_thresh_n)
        }))

    return(d)
}

ici = function(d){
    NULL
}

range_check = function(d, flagd){
    # d=pldf;flagd=flagdf

    ranges = list(
        'DO_mgL'=c(-0.5, 40),
        'DOSecondary_mgL'=c(0, 40),
        'satDO_mgL'=c(0, 30),
        'DOsat_pct'=c(0, 200),
        'WaterTemp_C'=c(-100, 100),
        'WaterTemp2_C'=c(-100, 100),
        'WaterTemp3_C'=c(-100, 100),
        'WaterPres_kPa'=c(0, 1000),
        'AirTemp_C'=c(-200, 100),
        'AirPres_kPa'=c(0, 110),
        'Level_m'=c(-10, 100),
        'Depth_m'=c(0, 100),
        'Discharge_m3s'=c(0, 250000),
        'Velocity_ms'=c(0, 10),
        'pH'=c(0, 14),
        'pH_mV'=c(-1000, 1000),
        'CDOM_ppb'=c(0, 10000),
        'CDOM_mV'=c(0, 10000),
        'FDOM_mV'=c(0, 10000),
        'Turbidity_NTU'=c(0, 500000),
        'Turbidity_mV'=c(0, 100000),
        'Turbidity_FNU'=c(0, 500000),
        'Nitrate_mgL'=c(0, 1000),
        'SpecCond_mScm'=c(0, 1000),
        'SpecCond_uScm'=c(0, 100000),
        'CO2_ppm'=c(0, 100000),
        'ChlorophyllA_ugL'=c(0, 1000),
        'Light_lux'=c(0, 1000000),
        'Light_PAR'=c(0, 100000),
        'Light2_lux'=c(0, 1000000),
        'Light2_PAR'=c(0, 100000),
        'Light3_lux'=c(0, 1000000),
        'Light3_PAR'=c(0, 100000),
        'Light4_lux'=c(0, 1000000),
        'Light4_PAR'=c(0, 100000),
        'Light5_lux'=c(0, 1000000),
        'Light5_PAR'=c(0, 100000),
        'underwater_lux'=c(0, 1000000),
        'underwater_PAR'=c(0, 100000),
        'benthic_lux'=c(0, 1000000),
        'benthic_PAR'=c(0, 100000),
        'EC_uScm'=c(0, 100000),
        'Battery_V'=c(0, 1000))

    for(c in colnames(d)){
        if(all(is.na(d[[c]]))) next
        rmin = ranges[[c]][1]
        rmax = ranges[[c]][2]
        flagd[[c]] = as.numeric(! is.na(d[[c]]) &
            (d[[c]] < rmin | d[[c]] > rmax))
    }

    d[flagd == 1] = NA

    return(list('d'=d, 'flagd'=flagd))
}

basic_outlier_detect = function(d, flagd, dtcol){

    variables = colnames(d)
    diffs = as.data.frame(apply(d, 2, diff))
    diffs$dt = dtcol[-1]
    d$dt = dtcol

    #original method
    heuristically_detected_outls = find_outliers(d)

    #additional methods
    for(vv in variables){

        alpha = 0.01
        if(vv %in% c('Level_m', 'Depth_m', 'Discharge_m3s')) alpha = 0.0001
        if(sum(is.na(diffs[, vv])) / nrow(diffs) > 0.99) next

        #find extreme points
        anom_d = as_tibble(d) %>%
            time_decompose(vv, method='twitter', message=FALSE)
        anom_d = tryCatch({
                anomalize(anom_d, remainder, max_anoms=0.01,
                alpha=alpha, method='gesd')
            }, error=function(e) {
                anomalize(anom_d, remainder, max_anoms=0.01,
                alpha=alpha, method='iqr')
            })
        outls1 = which(anom_d$anomaly == 'Yes')

        #find extreme jumps
        anom_d = as_tibble(diffs) %>%
            time_decompose(vv, method='twitter', message=FALSE)
        anom_d = tryCatch({
                anomalize(anom_d, remainder, max_anoms=0.01,
                    alpha=alpha, method='gesd')
            }, error=function(e) {
                anomalize(anom_d, remainder, max_anoms=0.01,
                    alpha=alpha, method='iqr')
            })
        outls2 = which(anom_d$anomaly == 'Yes') + 1

        #find super extreme points
        anom_d = as_tibble(d) %>%
            time_decompose(vv, method='twitter', message=FALSE)
        anom_d = tryCatch({
                anomalize(anom_d, remainder, max_anoms=0.001,
                    alpha=alpha, method='gesd')
            }, error=function(e) {
                anomalize(anom_d, remainder, max_anoms=0.001,
                    alpha=alpha, method='iqr')
            })
        outls3 = which(anom_d$anomaly == 'Yes')

        outls4 = heuristically_detected_outls[[vv]]
        if(length(outls4) == 1 && outls4 == 'NONE') outls4 = NULL

        #potential outliers = overlap of extreme points+jumps (1, 2, 4),
        outls = base::intersect(base::intersect(outls1, outls2), outls4)

        #or just super extreme points (3)
        outls = base::union(outls, outls3)

        if(! is.null(outls)){
            flagd[outls, vv] = flagd[outls, vv] + 2
        }
    }

    d$dt = NULL
    d[flagd > 0] = NA

    return(list('d'=d, 'flagd'=flagd))
}

testplot = function(d, xmin=NULL, xmax=NULL, ylims=NULL,
    showpoints=FALSE){

    ranges = list(
        'DO_mgL'=c(-0.5, 40),
        'DOSecondary_mgL'=c(0, 40),
        'satDO_mgL'=c(0, 30),
        'DOsat_pct'=c(0, 200),
        'WaterTemp_C'=c(-100, 100),
        'WaterTemp2_C'=c(-100, 100),
        'WaterTemp3_C'=c(-100, 100),
        'WaterPres_kPa'=c(0, 1000),
        'AirTemp_C'=c(-200, 100),
        'AirPres_kPa'=c(0, 110),
        'Level_m'=c(-10, 100),
        'Depth_m'=c(0, 100),
        'Discharge_m3s'=c(0, 250000),
        'Velocity_ms'=c(0, 10),
        'pH'=c(0, 14),
        'pH_mV'=c(-1000, 1000),
        'CDOM_ppb'=c(0, 10000),
        'CDOM_mV'=c(0, 10000),
        'FDOM_mV'=c(0, 10000),
        'Turbidity_NTU'=c(0, 500000),
        'Turbidity_mV'=c(0, 100000),
        'Turbidity_FNU'=c(0, 500000),
        'Nitrate_mgL'=c(0, 1000),
        'SpecCond_mScm'=c(0, 1000),
        'SpecCond_uScm'=c(0, 100000),
        'CO2_ppm'=c(0, 100000),
        'ChlorophyllA_ugL'=c(0, 1000),
        'Light_lux'=c(0, 1000000),
        'Light_PAR'=c(0, 100000),
        'Light2_lux'=c(0, 1000000),
        'Light2_PAR'=c(0, 100000),
        'Light3_lux'=c(0, 1000000),
        'Light3_PAR'=c(0, 100000),
        'Light4_lux'=c(0, 1000000),
        'Light4_PAR'=c(0, 100000),
        'Light5_lux'=c(0, 1000000),
        'Light5_PAR'=c(0, 100000),
        'underwater_lux'=c(0, 1000000),
        'underwater_PAR'=c(0, 100000),
        'benthic_lux'=c(0, 1000000),
        'benthic_PAR'=c(0, 100000),
        'EC_uScm'=c(0, 100000),
        'Battery_V'=c(0, 1000))

    ns = sqrt(ncol(d))
    nr = ceiling(ns)
    nc = floor(ncol(d) / ns)
    ptype = ifelse(showpoints, 'b', 'l')
    par(mfrow=c(nr, nc))
    for(c in colnames(d)){

        if(is.null(xmin)){
            xmin = origdf$DateTime_UTC[1]
        } else {
            xmin = as.POSIXct(xmin)
        }
        if(is.null(xmax)){
            xmax = origdf$DateTime_UTC[nrow(origdf)]
        } else {
            xmax = as.POSIXct(xmax)
        }
        if(is.null(ylims)){
            plot(origdf$DateTime_UTC, d[[c]], type=ptype, xlim=c(xmin, xmax),
                ylab=c, main=paste(xmin, xmax))
        } else {
            plot(origdf$DateTime_UTC, d[[c]], type=ptype, xlim=c(xmin, xmax),
                ylim=ylims, ylab=c, main=paste(xmin, xmax))
        }

        abline(h=ranges[[c]], lty=3, col='blue', lwd=2)
        origspec_color = plspec_color = rep(NA, nrow(origdf))

        plspecials = d[[c]]
        plspecials[flagdf[[c]] == 0] = NA
        # plspec_color = as.character(plspecials)
        plspec_color[flagdf[[c]] == 4] = 'green'
        # plspec_color[flagdf[[c]] != 4] = NA
        points(origdf$DateTime_UTC, plspecials, col=plspec_color)


        origspecials = origdf[[c]]
        origspecials[flagdf[[c]] == 0] = NA
        # origspec_color = as.character(origspecials)
        origspec_color[flagdf[[c]] == 1] = 'red'
        origspec_color[flagdf[[c]] == 2] = 'orange'
        # origspec_color[flagdf[[c]] != 4] = NA
        points(origdf$DateTime_UTC, origspecials, col=origspec_color)
    }
}

whichflags = function(){
    f = Reduce(function(w, y) union(w, y), Map(function(z) unique(z), flagdf))
    return(f)
}
