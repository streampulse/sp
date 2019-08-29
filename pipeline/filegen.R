library(StreamPULSE)

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

train = prep_metabolism(train, fillgaps='interpolation', maxhours=Inf,
    rm_flagged='none')
test = prep_metabolism(test, fillgaps='none', rm_flagged='none')

train_len = length(train$data)
labeled_anoms = data.frame(character(), character(),
    character(), character(), numeric())
varname_map = list("DO.obs"='DO_mgL', "DO.sat"='DOsat_pct',
    "depth"='Depth_m', "temp.water"='WaterTemp_C', "light"='Light_PAR',
    "discharge"='Discharge_m3s')
for(v in vars){
    v2 = names(varname_map)[varname_map == v]
    streamMetabolizer::convert_solartime_to_UTC(train$data$solar.time,
        longitude=train$specs)
    #HERE #########################
    train$data$solar.time   #CRAP: dt and solar time dont line up
    anom_seq = paste0('[',
        paste0('[', anomstarts, ', ', anomstops, ']', collapse=', '),
        ']')
    labeled_anoms = rbind(labeled_anoms,
        data.frame(v, 'lol', anom_seq, '[point]', train_len))
}
colnames(labeled_anoms) = c('chan_id', 'spacecraft', 'anomaly_sequences',
    'class', 'num_values')


write.csv(train$data, '~/Downloads/telemanom/training_dev/trainMud.csv',
    row.names=FALSE)
write.csv(test$data, '~/Downloads/telemanom/training_dev/testMud.csv',
    row.names=FALSE)
write.csv(labeled_anoms, '~/Downloads/telemanom_hmm/labeled_anomalies.csv',
    row.names=FALSE)
