# library(stringr)
library(tidyverse)
library(imputeTS)
library(anomalize)

setwd('/home/mike/git/streampulse/server_copy/sp')
# setwd('/home/aaron/sp')

source('pipeline/helpers.R')

#retrieve arguments passed from app.py
args = commandArgs(trailingOnly=TRUE)
names(args) = c('notificationEmail', 'tmpcode', 'region', 'site')

# #read in gmail password
# conf = readLines('config.py')
# extract_from_config = function(key){
#     ind = which(lapply(conf, function(x) grepl(key, x)) == TRUE)
#     val = str_match(conf[ind], '.*\\"(.*)\\"')[2]
#     return(val)
# }
# pw = extract_from_config('GRDO_GMAIL_PW')

#read in dataset saved during first part of upload process
# x = read_csv('/home/mike/Dropbox/streampulse/data/pipeline/1.csv')
# x = read.csv('/home/mike/Dropbox/streampulse/data/pipeline/1.csv',
#     stringsAsFactors=FALSE)
# z = x

z = read.csv(paste0('../spdumps/', args['tmpcode'], '_xx.csv'),
    stringsAsFactors=FALSE)
z = select(z, DateTime_UTC, everything()) %>%
    mutate(DateTime_UTC=as.POSIXct(x$DateTime_UTC, tz='UTC'))

#create df of same structure as data, to hold flag information
flagdf = z
flagdf[, 2:(ncol(flagdf) - 1)] = 0

#trim data before processing; datetime and upload id will be reattached at end
dtcol = z$DateTime_UTC
upload_id = z$upload_id
z$DateTime_UTC = NULL
z$upload_id = NULL

# impute gaps, ignoring series that are 95% gap or more
z = as.data.frame(apply(z, 2,
    function(x){
        if(sum(is.na(x)) / length(x) > 0.95) return(x)
        imputeTS::na_interpolation(x, option='linear')
    }))

#operation 1: simple range checker
#flags anything that's physically impossible with code 1
df_and_flagcodes = range_check(z, flagdf)
z = df_and_flagcodes$df
flagdf = df_and_flagcodes$flagdf

#operation 2: residual error based outlier detection with anomalize package
#flags outliers with code 2
df_and_flagcodes = basic_outlier_detect(z, flagdf)
df = df_and_flagcodes$df
flagdf = df_and_flagcodes$flagdf

