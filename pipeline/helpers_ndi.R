
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

# df=pldf; maxspan_days=5; knn=3; interv=15
NDI = function(df, knn=3, interv){

    samples_per_day = 24 * 60 / interv

    df_ = as_tibble(df) %>%
        bind_cols(origdf[,1]) %>%
        arrange(DateTime_UTC) %>%
        group_by(DateTime_UTC) %>%
        summarize_all(mean, na.rm=TRUE) %>%
        ungroup() %>%
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
    df = select(df_, -date) %>% as.data.frame()

    return(df)
}
