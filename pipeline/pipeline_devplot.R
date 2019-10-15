rm(list=ls()); cat('/014')

# library(sourcetools)
# library(stringr)
library(dplyr)
# library(zoo)
library(imputeTS)

#retrieve arguments passed from app.py
# args = commandArgs(trailingOnly=TRUE)
# names(args) = c('notificationEmail', 'tmpcode', 'region', 'site')

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
x = read.csv('~/Dropbox/streampulse/data/pipeline/1.csv',
    stringsAsFactors=FALSE)
x = select(x, DateTime_UTC, everything())
x$DateTime_UTC = as.POSIXct(x$DateTime_UTC, tz='UTC')
# x$DateTime_UTC = as.POSIXlt(x$DateTime_UTC, tz='UTC')
z = x
# z = head(x)

flagdf = z
flagdf[, 2:(ncol(flagdf) - 1)] = 0

# sensorcols = which(! colnames(z) %in% c('DateTime_UTC','upload_id'))
dtcol = z$DateTime_UTC
upload_id = z$upload_id
z$DateTime_UTC = NULL
z$upload_id = NULL

#pipeline
z = as.data.frame(apply(z, 2,
    function(x){
        if(sum(is.na(x)) / length(x) > 0.95) return(x)
        # zoo::na.approx(x, na.rm=FALSE, rule=2)
        imputeTS::na_interpolation(x, option='linear')
    }))

# z[seq(10, 25010, 5000), ] = -50
z[2:10, ] = 2; z[1000:1020, ] = 10

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

        for(c in colnames(df)){
            if(all(is.na(df[[c]]))) next
            rmin = ranges[[c]][1]
            rmax = ranges[[c]][2]
            flagdf[[c]] = as.numeric(df[[c]] < rmin | df[[c]] > rmax)
        }

        return(list('df'=df, 'flagdf'=flagdf))
}

df_and_flagcodes = range_check(z, flagdf)
df = df_and_flagcodes$df
flagdf = df_and_flagcodes$flagdf


#anomalize
library(anomalize)
# x$DateTime_UTC = as.POSIXct(x$DateTime_UTC, tz='UTC')
diffs = as.data.frame(apply(df, 2, diff))
# dtcol_diff = dtcol[-1]

par(mfrow=c(2,3), mar=c(0,0,3,0))
for(i in 1:ncol(diffs)){
    if(all(is.na(diffs[,i]))){
        plot(1,1)
        next
    }
    plot(diffs[,i], type='l', main=colnames(diffs)[i])
}

diffs$dt = dtcol[-1]
df$dt = dtcol

for(c in colnames(diffs)){
    alpha = 0.01
    if(c %in% c('Level_m', 'Depth_m', 'Discharge_m3s')) alpha=0.0001
    if(sum(is.na(diffs[, c])) / nrow(diffs) > 0.99) next

    #find extreme points
    anom_df = as_tibble(df) %>%
        time_decompose(c, method='twitter') %>%
        anomalize(remainder, max_anoms=0.01, alpha=alpha, method='gesd')
    outls1 = which(anom_df$anomaly == 'Yes')

    #find extreme jumps
    anom_df = as_tibble(diffs) %>%
        time_decompose(c, method='twitter') %>%
        anomalize(remainder, max_anoms=0.01, alpha=alpha, method='gesd')
    outls2 = which(anom_df$anomaly == 'Yes') + 1

    #find super extreme points
    anom_df = as_tibble(df) %>%
        time_decompose(c, method='twitter') %>%
        anomalize(remainder, max_anoms=0.001, alpha=alpha, method='gesd')
    outls3 = which(anom_df$anomaly == 'Yes')
    # anom_df = time_recompose(anom_df)
    # plot_anomalies(anom_df, time_recomposed=TRUE, ncol=1, alpha_dots=.2)

    #outls are overlap of extreme points+jumps, or just super extreme points
    outls = union(intersect(outls1, outls2), outls3)

    flagdf[outls, c] = flagdf[outls, c] + 2
}

# c = 'WaterTemp_C'
# library(dygraphs)
# library(xts)
par(mfrow=c(2,3), mar=c(0,2,3,0))
for(c in colnames(z)){
    if(all(is.na(diffs[, c]))){
        plot(1,1)
        next
    }
    # dydat = xts(z[,c], order.by=as.POSIXct(1:nrow(z), origin='1970-01-01'),
    #     tzone='UTC')
    # dimnames(dydat) = list(NULL, c)
    # dygraph(dydat, group='a') %>%
    #     dyOptions(useDataTimezone=TRUE, drawPoints=FALSE,
    #         colors='black', strokeWidth=1) %>%
    #     dyLegend(show='onmouseover', labelsSeparateLines=FALSE) %>%
    #     dyAxis('y', label=NULL, pixelsPerLabel=20, rangePad=10)
    #     # dySeries(

    plot(z[, c], type='l', main=c)
    range_exceed = which(flagdf[, c] == 1)
    outl_detect = which(flagdf[, c] %in% c(2, 3))
    points(range_exceed, z[range_exceed, c], col='red')
    points(outl_detect, z[outl_detect, c], col='orange')
}


#shit package
# data(raw_data)
res = AnomalyDetectionTs(x[,c(1,3)], max_anoms=0.02, direction='both', plot=TRUE)
# res = AnomalyDetectionVec(raw_data[,2], max_anoms=0.02, period=1440, direction='both',
#     only_last=FALSE, plot=TRUE)
res = AnomalyDetectionVec(x[,4], max_anoms=0.4, period=96, direction='both',
    only_last=FALSE, plot=TRUE)
res$plot


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
