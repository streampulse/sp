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
z = head(x)
z[1,3] = -50; z[2,4] = 2000

flagdf = z
flagdf[, 2:(ncol(flagdf) - 1)] = 0

#pipeline
range_check = function(df, flagdf){

    ranges = list(
        'DO_mgL'=c(0, 50),
        'DOSecondary_mgL'=c(0, 50),
        'satDO_mgL'=c(0, 50),
        'DOsat_pct'=c(0, 200),
        'WaterTemp_C'=c(-100, 100),
        'WaterTemp2_C'=c(-100, 100),
        'WaterTemp3_C'=c(-100, 100),
        'WaterPres_kPa'=c(0, 1000),
        'AirTemp_C'=c(-200, 100),
        'AirPres_kPa'=c(0, 110),
        'Level_m'=c(0, 100),
        'Depth_m'=c(0, 100),
        'Discharge_m3s'=c(0, 250000),
        'Velocity_ms'=c(0, 10),
        'pH'=c(0, 14),
        'pH_mV'=c(-1000, 1000),
        'CDOM_ppb'=c(0, 2000),
        'CDOM_mV'=c(0, 10000),
        'FDOM_mV'=c(0, 10000),
        'Turbidity_NTU'=c(0, 500000),
        'Turbidity_mV'=c(0, 100000),
        'Turbidity_FNU'=c(0, 500000),
        'Nitrate_mgL'=c(0, 1000),
        'SpecCond_mScm'=c(-10000, 10000),
        'SpecCond_uScm'=c(-1000000, 1000000),
        'CO2_ppm'=c(0, 10000),
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
