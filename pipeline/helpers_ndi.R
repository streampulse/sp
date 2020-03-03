
# dwg=days_with_gaps; dwog=days_without_gaps; cmat=correlations; k=3; minvars=3
# i = j = 1
nearest_k_days = function(dwg, dwog, cmat, k, minvars){
    # dl: a list of dataframes, named by datestring, each containing all samples
    #   for the specified day
    # k: number of similar days to find for each day with missing data
    # minvars: min number of variables that can be used to infer a
    #   missing value

    if(length(dwg) == 0){
        usr_msg_code <<- '1'
        return('nothing to do')
    }

    if(length(dwog) < 30){
        usr_msg_code <<- '2'
        return('nothing to do')
    }


    # dwg_dtcols = lapply(dwg, function(x) x[, 'DateTime_UTC', drop=FALSE])
    # dwog_dtcols = lapply(dwog, function(x) x[, 'DateTime_UTC', drop=FALSE])
    # nondt_cols = which(colnames(dwg[[1]]) != 'DateTime_UTC')
    # dwg = lapply(dwg, function(x) x[, nondt_cols])

    nearest_days = matrix(NA, length(dwg), k, dimnames=list(names(dwg), NULL))
    for(i in 1:length(dwg)){

        day_scores = vector('numeric', length(dwog))
        for(j in 1:length(dwog)){

            #RMSD: root mean squared difference
            #CSRMSD: correlation-scaled RMSD
            #MCSRMSD: mean CSRMSD

            #get MCSRSD between each day and the current dwg
            squarediffs = try( (dwg[[i]] - dwog[[j]])^2 )
                # (dwg[[i]][, nondt_cols] - dwog[[j]][, nondt_cols])^2
            if(class(squarediffs) == 'try-error'){
                day_scores[j] = Inf
            } else {
                RMSDs = sqrt(colMeans(squarediffs, na.rm=FALSE))
                gapvars = names(RMSDs[which(is.na(RMSDs))])
                inverse_mean_gapvar_abscorrs = 1 -
                    colMeans(abs(cmat[gapvars, , drop=FALSE]))
                CSRMSDs = RMSDs * inverse_mean_gapvar_abscorrs

                if(sum(! is.na(CSRMSDs)) < minvars){
                    day_scores[j] = NA
                } else {
                    MCSRMSD = mean(CSRMSDs, na.rm=TRUE)
                    day_scores[j] = MCSRMSD
                }
            }
        }

        nearest_days[i,] = names(dwog)[order(day_scores)[1:3]]
    }

    return(nearest_days)
}

standardize_df = function(x){

    x_std = x
    datecols = which(colnames(x) %in% c('date', 'DateTime_UTC'))
    x_means = colMeans(x[, -datecols], na.rm=TRUE)
    x_sds = apply(x[, -datecols], 2, sd, na.rm=TRUE)
    x_std[, -datecols] = scale(x[, -datecols])

    return(list(x_std=x_std, x_means=x_means, x_sds=x_sds))
}

unstandardize_df = function(x_std, x_means, x_sds){

    x = x_std
    datecol = which(colnames(x) %in% c('date', 'DateTime_UTC'))
    x[, -datecol] = mapply(function(w, y, z) w * y + z,
        x_std[, -datecol], x_sds, x_means)

    return(x)
}

# dfx=df_std
listify = function(dfx, incomplete_days){

    df_incompletes = dfx %>%
        filter(date %in% incomplete_days) %>%
        select(-date)

    dtcol_fulldays = dfx %>%
        filter(! date %in% incomplete_days) %>%
        select(DateTime_UTC)

    datelist_fulldays = dfx %>%
        select(-DateTime_UTC) %>%
        filter(! date %in% incomplete_days) %>%
        plyr::dlply(plyr::.(date))

    datelist_fulldays = Map(function(x) as.matrix(select(x, -date)),
        datelist_fulldays)

    return(list(fulldays=datelist_fulldays, dtcol=dtcol_fulldays,
        incompletes=df_incompletes))
}

# dwg=gapdays_filled; dwog=days_without_gaps; orig_dtcol=listout$dtcol; incompletes=listout$incompletes
unlistify = function(dwg, dwog, orig_dtcol, incompletes){

    datelist_fulldays = append(dwg, dwog)
    listdates = as.Date(names(datelist_fulldays))
    datelist_fulldays = datelist_fulldays[order(listdates)]

    dfx = plyr::ldply(datelist_fulldays) %>%
        select(-.id) %>%
        bind_cols(orig_dtcol) %>%
        bind_rows(incompletes) %>%
        arrange(DateTime_UTC) %>%
        select(DateTime_UTC, everything())

    return(dfx)
}

# dwg=days_with_gaps; dwog=days_without_gaps
gap_fill = function(dwg, dwog, nearest_days){

    for(i in 1:length(dwg)){
        ddate = names(dwg[i])
        # lapply(d, function(x) rle(is.na(x))) #start here if maxgap wanted
        # too_long_na_series =
        dnearest = nearest_days[ddate,]
        dnmean = Reduce(`+`, dwog[dnearest]) / length(dnearest)
        dyhat = dwg[[i]] - dnmean
        dyhat = apply(dyhat, 2,
            function(x){
                if(sum(! is.na(x)) < 4) return(x)
                imputeTS::na_interpolation(x, option='linear')
            })
        dwg[[i]] = dnmean + dyhat
    }

    return(dwg)
}

# x=ndi_ind_list[[1]]; original_indices=twos; interv=15; original_dates=twodates
find_snappoints = function(x, ndi_sections_, original_indices, original_dates,
    interv){

    ds = median(x)

    if(length(x) %% 2 == 0){
        ds = c(floor(ds), ceiling(ds))
        ndi_datetimes = ndi_sections_[ds, 'DateTime_UTC']
        ndi_difftimes = difftime(ndi_datetimes,
            as.Date(ndi_datetimes[2]), units='days')
        ds = ds[which.min(abs(ndi_difftimes))]
    }

    gapsize = diff(as.numeric(substr(original_dates[c(ds - 1, ds)], 9, 10)))

    fullday_skip = FALSE
    if(gapsize > 1) fullday_skip = TRUE

    ds = original_indices[ds]

    # nsamps_to_midday = 24 * 60 / interv / 2
    # dbs = c(max(ds - nsamps_to_midday, original_indices[1]),
    #     #never going to reach midday, right?
    #     ds + nsamps_to_midday)
    # dbs = c()

    return(list('daystart'=ds, 'fullday_skip'=fullday_skip))
}

# df=pldf; knn=3; interv=15
NDI = function(df, knn=3, interv){

    samples_per_day = 24 * 60 / interv

    df_ = df %>%
        mutate(date=as.Date(lubridate::floor_date(DateTime_UTC, unit='day')))

    date_counts = table(df_$date)
    incomplete_days_ind = which(date_counts < samples_per_day)
    if(length(incomplete_days_ind) == 0){
        incomplete_days = NULL
    } else {
        incomplete_days = as.Date(names(incomplete_days_ind))
    }

    #make new df of standardized variables; grab moments by which to rescale
    std_out = standardize_df(df_)
    df_std = std_out$x_std

    listout = listify(df_std, incomplete_days)
    datelist_fulldays = listout$fulldays

    # find k nearest neighbors for each day with missing values
    days_with_gaps_bool = unlist(Map(function(x) any(is.na(x)), datelist_fulldays))
    days_with_gaps = datelist_fulldays[days_with_gaps_bool]
    days_without_gaps = datelist_fulldays[! days_with_gaps_bool]
    correlations = cor(select(df_std, -date, -DateTime_UTC),
        use='na.or.complete', method='spearman')

    nearest_days = nearest_k_days(days_with_gaps, days_without_gaps,
        cmat=correlations, k=knn, minvars=3)

    if(length(nearest_days) == 1 && nearest_days == 'nothing to do'){
        return(df)
    }

    #perform NDI; return data to original shape and format
    gapdays_filled = gap_fill(days_with_gaps, days_without_gaps, nearest_days)

    df_std = unlistify(gapdays_filled, days_without_gaps, listout$dtcol,
        listout$incompletes)
    df_ = unstandardize_df(df_std, std_out$x_means, std_out$x_sds)
    # df = as.data.frame(select(df_, -DateTime_UTC))
    df = as.data.frame(df_)

    return(df)
}

rle_custom = function(x){
    r = rle(x)
    ends = cumsum(r$lengths)
    r = cbind(values=r$values,
        starts=c(1, ends[-length(ends)] + 1),
        stops=ends, lengths=r$lengths, deparse.level=1)
    return(r)
}

# dfcols_=dfcols; flagdf_=flagdf; ndiout_=ndiout; pldf_=pldf
snap_days = function(dfcols_, flagdf_, ndiout_, pldf_){

    for(c in dfcols_[dfcols_ != 'DateTime_UTC']){

        twos = which(flagdf_[[c]] == 2)
        # plot(ndiout_$DateTime_UTC, ndiout_$pH, col='orange', type='l', lwd=2)
        # lines(pldf_$DateTime_UTC, pldf_$pH, lwd=2)

        if(length(twos)){

            twodates = ndiout_$DateTime_UTC[twos]
            ndi_sections = ndiout_[twos, c('DateTime_UTC', c)]

            #get new day indices within NDI sections
            ndi_rounded_dates = round(ndi_sections$DateTime_UTC, 'hour')
            daystarts = which(substr(ndi_rounded_dates, 12, 19) ==
                '00:00:00')

            if(! length(daystarts)){
                next
            }

            r = rle_custom(diff(daystarts))
            r = r[r[, 'values'] == 1, , drop=FALSE]

            if(nrow(r) > 1){
                r = r[-nrow(r), , drop=FALSE]
            }

            ds_fac = cut(1:length(daystarts), c(0, r[, 'stops'] + 1, Inf))
            ndi_ind_list = split(daystarts, ds_fac, drop=TRUE)
            ndi_list = unname(lapply(ndi_ind_list,
                find_snappoints, ndi_sections, twos, twodates, samp_int_m))
            # ndi_list = Filter(function(x) ! is.null(x), ndi_list)

            if(! length(ndi_list)){
                next
            }

            #identify NDI sections in which multiple days abut.
            #these need to be edge-snapped
            ndi_edges = rle_custom(flagdf_[[c]] == 2)
            ndi_edges = ndi_edges[ndi_edges[, 'values'] == 1, , drop=FALSE]
            na_edges = rle_custom(is.na(pldf_[[c]]))
            na_edges = na_edges[na_edges[, 'values'] == 1, , drop=FALSE]

            fullday_skips = matrix(ncol=4, nrow=2,
                dimnames=list(NULL, c('values', 'starts', 'stops', 'lengths')))
            fullday_skips = fullday_skips[-(1:2),]
            for(j in nrow(ndi_edges):1){
                gapless_ndi = paste(ndi_edges[j, 'starts'],
                    ndi_edges[j, 'stops']) %in%
                    paste(na_edges[, 'starts'], na_edges[, 'stops'])
                if(! gapless_ndi){
                    fullday_skips = rbind(fullday_skips,
                        ndi_edges[j, , drop=FALSE])
                    ndi_edges = ndi_edges[-j, , drop=FALSE]
                }
            }
            fullday_skips = fullday_skips[nrow(fullday_skips):1, ]

            #make sure everything is chill.
            #associate NDI section boundaries with newday indices
            if(nrow(ndi_edges)){

                ndi_edges = alply(ndi_edges, 1, function(x){
                    list(matrix(x, nrow=1))
                })

                fds_bool = sapply(ndi_list, function(x) x$fullday_skip)

                if(any(fds_bool)){
                    for(k in 1:length(ndi_list[fds_bool])){
                        ds_k = ndi_list[fds_bool][[k]]$daystart
                        if(ds_k != fullday_skips[k * 2, 2]){
                            stop('not chill')
                        }
                    }
                }

                if(any(! fds_bool)){
                    ds_db_lined_up = all(mapply(function(x, y){
                        x$daystart >= y[[1]][2] && x$daystart <= y[[1]][3]
                    }, ndi_list[! fds_bool], ndi_edges))

                    if(! ds_db_lined_up){
                        stop('not chill')
                    }
                }

                ndi_list[! fds_bool] = mapply(function(x, y){
                    x$bounds = y[[1]][2:3]
                    return(x)
                }, ndi_list[! fds_bool], ndi_edges, SIMPLIFY=FALSE)

                for(k in 1:length(ndi_list[fds_bool])){
                    fds_bounds = c(fullday_skips[k * 2 - 1, 2],
                        fullday_skips[k * 2, 3])
                    ndi_list[fds_bool][[k]]$bounds = fds_bounds
                }

            } else {
                next
            }

            #snap NDI day edges:
            #adjust values linearly toward midpoint in proportion to the length
            #of each dangling side
            for(j in 1:length(ndi_list)){

                ndi_section = ndi_list[[j]]
                ds = ndi_section$daystart
                lb = ndi_section$bounds[1]
                rb = ndi_section$bounds[2]
                dend = Position(function(x) ! is.na(x),
                    ndiout_[lb:(ds - 1), c], right=TRUE) + lb - 1
                # points(ndiout_$DateTime_UTC[dend],
                #     ndiout_$AirPres_kPa[dend], col='blue')
                # points(ndiout_$DateTime_UTC[c(ds, dend)],
                #     ndiout_$AirPres_kPa[c(ds, dend)], col='blue')
                # points(ndiout_$DateTime_UTC[c(lb, rb)],
                #     ndiout_$AirPres_kPa[c(lb, rb)], col='darkgreen')

                # if(ndi_section$fullday_skip){
                #
                # } else {
                ndilen = rb - lb + 1
                na_len = sum(is.na(ndiout_[lb:rb, c]))
                snapdist = diff(ndiout_[c(dend, ds), c])
                snapdist = snapdist * ((ndilen - na_len) / ndilen)
                ndilen_l = dend - lb + 1
                ndilen_r = rb - ds + 1
                snapprop_l = ndilen_l / ndilen
                snapprop_r = 1 - snapprop_l
                snapshift_l = seq(0, snapdist * snapprop_l,
                    length.out=ndilen_l)
                snapshift_r = seq(-1 * snapdist * snapprop_r, 0,
                    length.out=ndilen_r)

                ndiout_[lb:dend, c] = ndiout_[lb:dend, c] + snapshift_l
                ndiout_[ds:rb, c] = ndiout_[ds:rb, c] + snapshift_r
                # lines(ndiout_$DateTime_UTC, ndiout_$AirPres_kPa, col='red')
                # lines(pldf$DateTime_UTC, pldf$AirPres_kPa)

            }
        }
    }

    return(ndiout_)
}
