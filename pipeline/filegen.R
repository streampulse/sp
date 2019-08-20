library(StreamPULSE)
train = request_data(sitecode='WI_BEC', startdate='2018-02-14',
    enddate='2018-03-28', variables=c('Level_m', 'Turbidity_NTU', 'Watertemp_C',
        'Discharge_m3s', 'DO_mgL'))
train = prep_metabolism(train, fillgaps='interpolation', maxhours=Inf)
# plot(z$data$solar.time, z$data$temp.water,
#     xlim=as.POSIXct(c('2018-03-05', '2018-04-09'), tz = 'UTC'))

test = request_data(sitecode='WI_BEC', startdate='2018-03-29',
    enddate='2018-07-31', variables=c('Level_m', 'Turbidity_NTU', 'Watertemp_C',
        'Discharge_m3s', 'DO_mgL'))
test = prep_metabolism(test, rm_flagged='none', fillgaps='locf', maxhours=Inf)

write.csv(test$data, '~/Downloads/telemanom/training_dev/test.csv', row.names=FALSE)
write.csv(train$data, '~/Downloads/telemanom/training_dev/train.csv', row.names=FALSE)
head(train$data)
