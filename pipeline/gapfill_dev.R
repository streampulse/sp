# dl=datelist_fulldays; cmat=correlations; k=3; minobs=3
nearest_k_days = function(dwg, dwog, k, minvars){
    # dl: a list of dataframes, named by datestring, each containing all samples
    #   for the specified day
    # k: number of similar days to find for each day with missing data
    # minvars: min number of variables that can be used to infer a
    #   missing value

    # enough_full_days = TRUE
    if(length(dwog) < 30){
        usr_msgs = append(usr_msgs,
            paste('Not filling gaps via ICI;',
            'fewer than 30 days without NAs for comparison.'))
        stop()
        # enough_full_days = FALSE
    }

    nearest_days = matrix(NA, length(dwg), k, dimnames=list(names(dwg), NULL))
    for(i in 1:length(dwg)){

        day_scores = vector('numeric', length(dwog))
        for(j in 1:length(dwog)){

            #get sums of squared differences between each day and the current dwg
            d = try( (dwg[[i]] - dwog[[j]])^2 )
            if(class(d) == 'try-error'){
                day_scores[j] = Inf
            } else {
                ssds = colSums(d, na.rm=FALSE)

                if(sum(! is.na(ssds)) < minvars){
                    day_scores[j] = NA
                } else {
                    mean_ssd = mean(ssds, na.rm=TRUE)
                    day_scores[j] = mean_ssd
                }
            }
        }

        nearest_days[i,] = names(dwog)[order(day_scores)[1:3]]
    }

    return(nearest_days)
}

listify_df = function(dfx){

    datelist_fulldays = dfx %>%
        filter(! date %in% incomplete_days) %>%
        plyr::dlply(plyr::.(date))

    datelist_fulldays = Map(function(x) as.matrix(select(x, -date)),
        datelist_fulldays)

    return(datelist_fulldays)
}

unlistify_df = function(dlx){

    # datelist_fulldays = dfx %>%
    #     filter(! date %in% incomplete_days) %>%
    #     plyr::dlply(plyr::.(date))
    #
    # datelist_fulldays = Map(function(x) as.matrix(select(x, -date)),
    #     datelist_fulldays)

    return(datelist_fulldays)
}

dwg=days_with_gaps; dwog=days_without_gaps
NDI = function(dwg, dwog, nearest_days){
    #nearest days interpolation

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

df=pldf; maxspan_days=5; knn=3; interv=15
sint=desired_int; algorithm=fillgaps
gap_fill = function(df, maxspan_days=5, knn=3, interv, algorithm, ...){

    # # kind of goofy to do this by date and time, but that's because I
    # # translated the code from Python
    # input_data = df %>% mutate(date=as.Date(df[,dtcol]),
    #     time=strftime(df[,dtcol], format="%H:%M:%S")) %>%
    #     select(-one_of(dtcol)) %>% select(date, time, everything())
    # date_index = df %>% select(one_of(dtcol)) # index data

    #get daily sampling frequency so imputation can leverage periodicity
    samples_per_day = 24 * 60 / interv
    # samples_per_day = 24 * 60 / as.double(sint, units='mins')

    df = as_tibble(df) %>%
        bind_cols(origdf[,1]) %>%
        arrange(DateTime_UTC) %>%
        group_by(DateTime_UTC) %>%
        summarize_all(mean, na.rm=TRUE) %>%
        ungroup() %>%
        mutate(date=as.Date(lubridate::floor_date(DateTime_UTC, unit='day'))) %>%
        select(-DateTime_UTC)

    # correlations = cor(select(df, -date), use='na.or.complete', method='kendall')
    correlations = cor(select(df, -date), use='na.or.complete', method='spearman')

    date_counts = table(df$date)

    incomplete_days = as.Date(names(which(date_counts < samples_per_day)))

    #make new df of standardized variables
    df_std = df
    #gotta grab means and sds here to rescale with
    df_std[, 1:(ncol(df) - 1)] = apply(df[, 1:(ncol(df) - 1)], 2, scale)

    datelist_fulldays = listify_df(df_std)

    # find k nearest neighbors for each day index
    days_with_gaps_bool = unlist(Map(function(x) any(is.na(x)), datelist_fulldays))
    days_with_gaps = datelist_fulldays[days_with_gaps_bool]
    days_without_gaps = datelist_fulldays[! days_with_gaps_bool]

    nearest_days = nearest_k_days(days_with_gaps, days_without_gaps,
        k=knn, minvars=3)

        #calculate a weighted sum of squared differences between corresponding
        #values for each day, based on correlation strengths

    gapdays_filled = NDI(days_with_gaps, days_without_gaps, nearest_days)

    datelist_fulldays = unlistify_df(df_std)


    # filld <- which(complete.cases(ns))
    union(names(datelist_fulldays), rownames(nearest_days))
    rle(diff(as.numeric(as.Date(rownames(nearest_days)))))


    filled = fill_missing(datelist_fulldays, nearest_days)

    #remove columns with 0 or 1 non-NA value. these cannot be imputed.
    vals_per_col = apply(filled[,-1], 2, function(x) sum(!is.na(x)))
    too_few_val_cols = vals_per_col %in% c(0,1)
    if(any(too_few_val_cols)){
        too_few_val_cols = colnames(filled)[-1][too_few_val_cols]
        filled = filled[,!colnames(filled) %in% too_few_val_cols]
        warning(paste0('Too few values in ',
            paste(too_few_val_cols, collapse=', '),
            '.\n\tDropping column(s), which may result in fatal error.'),
            call.=FALSE)
    }

    #linearly impute any remaining gaps
    filled[is.na(filled)] = NA #replace any NaNs with NAs
    filled[,-1] = apply(filled[,-1], 2, na.fill, 'extend')
    # print(sum(is.na(filled)))

    return(filled)
    # return(input_data)
}
