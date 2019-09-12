library(StreamPULSE)
library(tidyr)
library(dplyr)
library(zoo)

#for rrcf/anomalize/generic ####
train = request_data(sitecode='WI_BEC', startdate='2018-02-14',
    enddate='2018-03-28', variables=c('Level_m', 'Turbidity_NTU', 'Watertemp_C',
        'Discharge_m3s', 'DO_mgL'))
train = prep_metabolism(train, fillgaps='interpolation', maxhours=Inf)
# plot(z$data$solar.time, z$data$temp.water,
#     xlim=as.POSIXct(c('2018-03-05', '2018-04-09'), tz = 'UTC'))

test = request_data(sitecode='WI_BEC', startdate='2018-03-29',
    enddate='2018-07-31', variables=c('Level_m', 'Turbidity_NTU', 'Watertemp_C',
        'Discharge_m3s', 'DO_mgL'))
test = request_data(sitecode='AT_YRN116', startdate='2013-03-15', token='1450f8bb26d278c72df8',
    enddate='2013-04-20', variables=c('Watertemp_C', 'Discharge_m3s', 'DO_mgL'))
test = prep_metabolism(test, rm_flagged='none', fillgaps='locf', maxhours=Inf,
    estimate_areal_depth=TRUE)

write.csv(train$data, '~/Downloads/telemanom/training_dev/train.csv', row.names=FALSE)
write.csv(test$data, '~/Downloads/telemanom/training_dev/testAT.csv', row.names=FALSE)
head(train$data)

#for trained detector ####
train = request_data(sitecode='NC_Mud', startdate='2007-01-01',
    enddate='2009-06-01', variables=c('Level_m', 'WaterTemp_C',
        'Discharge_m3s', 'DO_mgL'))

test = request_data(sitecode='NC_Mud', startdate='2009-06-02',
    enddate='2011-01-01', variables=c('Level_m', 'WaterTemp_C',
        'Discharge_m3s', 'DO_mgL'))
train0 = train
test0 = test
# train = train0
# test = test0
# d = train
# d = d$data

vars = unique(train$data$variable)
anom_bounds_dt = list()
for(v in vars){
    trainv = train$data[train$data$variable == v, ]
    r = rle(trainv$flagtype != '')
    ends = cumsum(r$lengths)
    r = list(values=r$values,
        starts=c(1, ends[-length(ends)] + 1),
        stops=ends, lengths=r$lengths)

    anom_bounds_dt[[v]] = list()
    anom_bounds_dt[[v]]$anomstarts = trainv$DateTime_UTC[r$starts[r$values == TRUE]]
    anom_bounds_dt[[v]]$anomstops = trainv$DateTime_UTC[r$stops[r$values == TRUE]]
}
# train = prep_metabolism(train, fillgaps='interpolation', maxhours=Inf,
#     rm_flagged='none')
# test = prep_metabolism(test, fillgaps='none', rm_flagged='none')
prep = function(d){

    d = d$data

    #check for consistent sample interval (including cases where there are gaps
    #between samples and where the underying sample pattern changes)
    ints_by_var = data.frame(var=vars, int=rep(NA, length(vars)))
    for(i in 1:length(vars)){

        #get lengths and values for successive repetitions of the same
        #sample interval (using run length encoding)
        dt_by_var = sort(unique(d$DateTime_UTC[d$variable == vars[i]]))

        run_lengths = rle(diff(as.numeric(dt_by_var)))
        if(length(run_lengths$lengths) != 1){

            # if gaps or interval change, get mode interval
            uniqv = unique(run_lengths$values)
            input_int = as.numeric(names(which.max(tapply(run_lengths$lengths,
                run_lengths$values, sum)))) / 60

            if(any(uniqv %% min(uniqv) != 0)){ #if underlying pattern changes
                warning(paste0('Sample interval is not consistent for ', vars[i],
                    '\n\tGaps will be introduced!\n\t',
                    'Using the most common interval: ',
                    as.character(input_int), ' mins.'), call.=FALSE)
            } else {
                message(paste0(length(run_lengths$lengths)-1,
                    ' sample gap(s) detected in ', vars[i], '.'))
            }

            #store the (most common) sample interval for each variable
            ints_by_var[i,2] = as.difftime(input_int, unit='mins')

        } else {

            # if consistent, just grab the diff between the first two times
            ints_by_var[i,2] = difftime(dt_by_var[2],  dt_by_var[1],
                units='mins')
        }
    }

    #will later coerce all vars to the longest sample interval
    #unless `interval` is specified
    if(length(unique(ints_by_var$int)) > 1){
        input_int = max(ints_by_var$int)
        if(! is.na(interval)){
            message(paste0('Multiple sample intervals detected across variables (',
                paste(unique(ints_by_var$int), collapse=' min, '),
                ' min).\n\tWill attempt to coerce all variables to desired ',
                'interval: ', interval, '.'))
        } else {
            interval = paste(input_int, 'min')
            message(paste0('Multiple sample intervals detected across variables (',
                paste(unique(ints_by_var$int), collapse=' min, '),
                ' min).\n\tUsing ', input_int, ' so as not to introduce gaps.\n\t',
                'You may control this behavior with the "interval" parameter.'))
        }
    } else {
        input_int = ints_by_var$int[1] #all intervals equal
        interval = paste(input_int, 'min')
    }


    # dupedates = d$DateTime_UTC[duplicated(d[, c('DateTime_UTC', 'variable')])]
    # for(i in 1:length(dupedates)){
    #     d[,

    d = tidyr::spread(d, variable, value)
    dtfull = data.frame('DateTime_UTC'=seq.POSIXt(d$DateTime_UTC[1],
        d$DateTime_UTC[nrow(d)], by=interval))
    d = dplyr::left_join(dtfull, d)
    d[, 6:ncol(d)] = zoo::na.approx(d[, 6:ncol(d)], na.rm=FALSE, rule=2)
    d = data.frame(d)
    return(d)
}

train = prep(train)
test = prep(test)

train_len = length(train)
labeled_anoms = data.frame(character(), character(),
    character(), character(), numeric())
varname_map = list("DO.obs"='DO_mgL', "DO.sat"='DOsat_pct',
    "depth"='Depth_m', "temp.water"='WaterTemp_C', "light"='Light_PAR',
    "discharge"='Discharge_m3s')
for(v in vars){
    v2 = names(varname_map)[varname_map == v]
    anomstarts = anom_bounds_dt[[v]]$anomstarts
    anomstops = anom_bounds_dt[[v]]$anomstops
    anom_seq = paste0('[',
        paste0('[', anomstarts, ', ', anomstops, ']', collapse=', '),
        ']')
    labeled_anoms = rbind(labeled_anoms,
        data.frame(v, 'lol', anom_seq, '[point]', train_len))
}
colnames(labeled_anoms) = c('chan_id', 'spacecraft', 'anomaly_sequences',
    'class', 'num_values')
plot(train$DO_mgL, type='l')
bad_data = mapply(seq.POSIXt, anom_bounds_dt$DO_mgL$anomstarts,
    anom_bounds_dt$DO_mgL$anomstops, MoreArgs=list(by='15 min'))
bad_data = as.POSIXct(unlist(bad_data), origin='1970-01-01', tz='UTC')
points(bad_data, train[train$DateTime_UTC %in% bad_data,])

write.csv(train, '~/Downloads/telemanom/training_dev/trainMud.csv',
    row.names=FALSE)
write.csv(test, '~/Downloads/telemanom/training_dev/testMud.csv',
    row.names=FALSE)
write.csv(labeled_anoms, '~/Downloads/telemanom_hmm/labeled_anomalies.csv',
    row.names=FALSE)
