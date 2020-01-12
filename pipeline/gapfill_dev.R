# dl=datelist_fulldays; cmat=correlations; k=3; minobs=3
nearest_k_days = function(dl, k, minvars){
    # dl: a list of dataframes, named by datestring, each containing all samples
    #   for the specified day
    # k: number of similar days to find for each day with missing data
    # minvars: min number of variables that can be used to infer a
    #   missing value

    days_with_gaps_bool = unlist(Map(function(x) any(is.na(x)), dl))
    dwg = dl[days_with_gaps_bool]
    dwog = dl[! days_with_gaps_bool]

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

# data prep function for fill_gaps
# adds snap points, gets average data
prep_missing = function(df, nearest_neighbors, daily_averages, mm, samp){
    # df is the data frame
    # daily_averages is the data frame of days
    # mm is the missing days
    # nearest_neighbors is the matching neighbors
    #
    ### MISSING DATA
    # df2 <<- df
    # nearest_neighbors2 <<- nearest_neighbors
    # daily_averages2 <<- daily_averages
    # mm2 <<- mm
    # samp2 <<- samp
    # stop('a')
    # df = df2
    # nearest_neighbors = nearest_neighbors2
    # daily_averages = daily_averages2
    # mm = mm2
    # samp = samp2

    missing = filter(df, date %in% daily_averages$date[mm])
    # if missing first and last obs, extend timeseries to include neighbor days
    #  unless first/last day
    if(any(!complete.cases(missing)[c(1,nrow(missing))])){
        if(mm[1]!=1) mm = c(mm[1]-1, mm) # if not first day, extend obs range
        if(tail(mm,1)!=nrow(daily_averages)) mm = c(mm, tail(mm,1)+1) # if not last day, extend obs range
        missing = filter(df, date%in%daily_averages$date[mm]) # missing one step interpolation
        # if any data missing still (i.e., first and last day), add avg of first and last obs
        #  this should catch most NAs for filling missing
        if(any(!complete.cases(missing)[c(1,nrow(missing))])){
            missing[c(1,nrow(missing)),-c(1,2)] =
                apply(missing[c(1,nrow(missing)),-c(1,2)], 2, mean, na.rm=T)
        }
    }
    ndays = length(mm)
    ### SIMILAR DATA
    # grab similar days - pairs of missing day and similar day
    ss = data.frame(date=daily_averages$date[mm],
        match=daily_averages$date[t(nearest_neighbors[mm,])])
    ss = ss[complete.cases(ss),]
    similar = left_join(ss, df, by=c("match"="date")) %>%
        select(-match) %>% group_by(date, time) %>% summarize_all(mean) %>%
        ungroup()
    # make sure that the dates in similar and missing line up
    missing = right_join(missing, select(similar,date,time),
        by=c("date","time"))
    ### DAILY SNAP POINTS
    # add snap points at beginning/end each new day to rescale and
    # match the daily trends
    newdaypoints = which(missing$time %in% missing$time[c(1,nrow(missing))])
    daypoints = missing[newdaypoints,]

    if(any(is.na(daypoints))){
        #tol should be greater here probably?
        dayfill = series_impute(select(daypoints,-date,-time), tol=0,
            samp=samp, algorithm='mean', variable_name=work-this-out)
        missing[newdaypoints,] = data.frame(date=daypoints$date,
            time=daypoints$time, dayfill)
    }
    list(missing=select(missing,-date,-time),
        similar=select(similar,-date,-time), index=select(similar,date,time))
}

# df=input_data; lim=0; samp=samples_per_day; g=1
fill_missing = function(df,
# fill_missing = function(df, nearest_neighbors, daily_averages,
    date_index, maxspan_days, samp, lim=0){

    #temporarily broken. see comment below.

    # df2 <<- df
    # nearest_neighbors2 <<- nearest_neighbors
    # daily_averages2 <<- daily_averages
    # date_index2 <<- date_index
    # maxspan_days2 <<- maxspan_days
    # samp2 <<- samp
    # break
    # df = df2
    # nearest_neighbors = nearest_neighbors2
    # daily_averages = daily_averages2
    # date_index = date_index2
    # maxspan_days = maxspan_days2
    # samp = samp2

    # df is the input data frame, all numeric data
    # nearest_neighbors are the similar days for each day
    # daily_averages is the daily data
    # date_index are the identifiers
    # maxspan_days is the maximum number of days to gap fill
    # lim is the minimum number of days to fill
    #     will not fill gaps that are less than this
    #     used for testing (b/c the test data have pre-existing gaps)


    #following chunk temporarily disabled. nearest neighbors gapfiller
    #needs work (also changed the parameter list)


    # the days that need filling in daily_averages
    # filld = which(complete.cases(nearest_neighbors))
    #
    # if(length(filld)){ #skip the rest if no data are missing
    #
    #     # groups for blocks of missing data
    #     group = cumsum(c(TRUE, diff(filld) > 1))
    #     # g = 1
    #     for(g in unique(group)){
    #
    #         # grab missing days
    #         mm = filld[group == g]
    #
    #         if(length(mm) >= lim && length(mm) <= maxspan_days){
    #             message('chunk requires operation')
    #             pp = prep_missing(df, nearest_neighbors, daily_averages, mm,
    #                 samp)
    #             dy = (pp$missing - pp$similar)
    #             message('before inexplicably stil existing linear_fill')
    #             dyhat = linear_fill(dy)
    #             filled = pp$similar + dyhat
    #             df[which(paste(df$date,df$time) %in%
    #                     paste(pp$index$date,pp$index$time)),-c(1,2)] = filled
    #         }
    #     }
    # }
    data.frame(date_index, select(df,-date,-time), stringsAsFactors=FALSE)
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
    df_std[, 1:(ncol(df) - 1)] = apply(df[, 1:(ncol(df) - 1)], 2, scale)

    datelist_fulldays = df_std %>%
        filter(! date %in% incomplete_days) %>%
        plyr::dlply(plyr::.(date))

    datelist_fulldays = Map(function(x) as.matrix(select(x, -date)),
        datelist_fulldays)

    # get averages for days with full sample coverage; otherwise NA (via mean())
    # nearly_complete_day = samples_per_day * 0.95 #could also use partial days
    # daily_averages = df %>%
    #     bind_cols(origdf[,1]) %>%
    #     mutate(date=lubridate::round_date(DateTime_UTC, unit='day')) %>%
    #     select(-DateTime_UTC) %>%
    #     group_by(date) %>%
    #     summarize_all(list(~ ( (n() == samples_per_day) * mean(.) ) ))
        # filter_at(vars(-date), any_vars(. != 0))

    # find k nearest neighbors for each day index
    nearest_days = nearest_k_days(datelist_fulldays, k=knn, minvars=3)
    # nearest_neighbors = top_k(select(daily_averages, -date), k=knn, minobs=3)

        #calculate a weighted sum of squared differences between corresponding
        #values for each day, based on correlation strengths

    # filled = fill_missing(input_data, nearest_neighbors, daily_averages,
    filled = fill_missing(input_data, date_index, maxspan_days,
        samp=samples_per_day)

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
