# library(sourcetools)
# library(stringr)

#retrieve arguments passed from app.py
args = commandArgs(trailingOnly=TRUE)
names(args) = c('notificationEmail', 'tmpcode', 'region', 'site')

# #read in gmail password
# setwd('/home/mike/git/streampulse/server_copy/sp')
# # setwd('/home/aaron/sp')
#
# conf = readLines('config.py')
# extract_from_config = function(key){
#     ind = which(lapply(conf, function(x) grepl(key, x)) == TRUE)
#     val = str_match(conf[ind], '.*\\"(.*)\\"')[2]
#     return(val)
# }
# pw = extract_from_config('GRDO_GMAIL_PW')

#read in dataset saved during first part of upload process
x = read.csv('~/Desktop/xxwide.csv', stringsAsFactors=FALSE)
x$DateTime_UTC = as.POSIXct(x$DateTime_UTC, tz='UTC')
# x$DateTime_UTC = as.POSIXlt(x$DateTime_UTC, tz='UTC')
z = head(x)
z[1,3] = -50; z[2,4] = 2000

flagdf = z
flagdf[, 2:(ncol(flagdf) - 1)] = 0

#pipeline
range_check = function(df, flagdf){

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
        'Battery_V'=c(0, 1000))

        for(c in colnames(df)[-c(1, ncol(df))]){
            rmin = ranges[[c]][1]
            rmax = ranges[[c]][2]
            flagdf[[c]] = as.numeric(df[[c]] < rmin | df[[c]] > rmax)
        }

        return(list('df'=df, 'flagdf'=flagdf))
}

df_and_flagcodes = range_check(z, flagdf)

#shit package
# data(raw_data)
res = AnomalyDetectionTs(x[,c(1,3)], max_anoms=0.02, direction='both', plot=TRUE)
# res = AnomalyDetectionVec(raw_data[,2], max_anoms=0.02, period=1440, direction='both',
#     only_last=FALSE, plot=TRUE)
res = AnomalyDetectionVec(x[,4], max_anoms=0.4, period=96, direction='both',
    only_last=FALSE, plot=TRUE)
res$plot

#anomalize
library(anomalize)
x$DateTime_UTC = as.POSIXct(x$DateTime_UTC, tz='UTC')
as_tibble(x) %>% time_decompose(WaterTemp_C) %>%
    anomalize(remainder) %>%
    time_recompose() %>%
    plot_anomalies(time_recomposed=TRUE, ncol=3, alpha_dots=.2)

#xgboost cart
library(xgboost)
# tst = data.frame(pH=diff(x[,3]))
tst = x[,3, drop=FALSE]
tst$ar1 = dplyr::lag(tst$pH)
tst$ar2 = dplyr::lag(tst$pH, 2)
tst$ar3 = dplyr::lag(tst$pH, 3)
tst$ar5 = dplyr::lag(tst$pH, 5)
tst$ar96 = dplyr::lag(tst$pH, 96)
tst$ma1 = as.numeric(residuals(arima(tst$pH, order=c(0,0,1), include.mean=TRUE)))
tst$ma2 = as.numeric(residuals(arima(tst$pH, order=c(0,0,2), include.mean=TRUE)))
tst$ma3 = as.numeric(residuals(arima(tst$pH, order=c(0,0,3), include.mean=TRUE)))
tst$ma5 = as.numeric(residuals(arima(tst$pH, order=c(0,0,5), include.mean=TRUE)))
# tst$ma96 = residuals(arima(tst$pH, order=c(0,0,96), include.mean=TRUE))
xgb = xgboost(data = data.matrix(tst[,-1]),
    label = tst[,1],
    eta = 0.1,
    max_depth = 15,
    nround=25,
    subsample = 0.5,
    colsample_bytree = 0.5,
    seed = 1,
    eval_metric = "merror",
    objective = "multi:softprob",
    num_class = 12,
    nthread = 3
)

plot(tst[,1], type='l')
par(new=T)
y = predict(xgb, data.matrix(tst[,-1]))
plot(y, type='l', col='red')

#lstm


# #notify user that it's done (to avoid java baloney, use python for this)
# # write(names(args), file='/home/mike/Desktop/foo.txt')

# #notify user that it's done
# email_template = 'static/email_templates/pipeline_complete.txt'
# # email_template = '/home/mike/git/streampulse/server_copy/sp/static/email_templates/pipeline_complete.txt'
# email_body = read(email_template)
#
# tmpurl = 'https://data.streampulse.org/pipeline-complete/' + args['tmpcode']
# email_body = sprintf(email_body, args['region'], args['site'],
#     args['tmpurl'], args['tmpurl'])
#
# send.mail(from='grdouser@gmail.com',
#     # to=c(args['notificationEmail']), subject='StreamPULSE upload complete',
#     to=c('vlahm13@gmail.com'), subject='StreamPULSE upload complete',
#     body=email_body, authenticate=TRUE, send=TRUE,
#     smtp=list(host.name='smtp.gmail.com', port=587,
#         user.name="grdouser@gmail.com",
#         passwd=pw, ssl=TRUE))
#
