library(tidyverse)
library(imputeTS)
library(anomalize)
library(feather)

setwd('/home/mike/git/streampulse/server_copy/sp')
# setwd('/home/aaron/sp')

source('pipeline/helpers.R')

#retrieve arguments passed from app.py
args = commandArgs(trailingOnly=TRUE)
names(args) = c('notificationEmail', 'tmpcode', 'region', 'site')

#read in dataset saved during first part of upload process
# x = read_csv('/home/mike/Dropbox/streampulse/data/pipeline/1.csv')
# x = read.csv('/home/mike/Dropbox/streampulse/data/pipeline/1.csv',
#     stringsAsFactors=FALSE)
# z = x

# z = read.csv(paste0('../spdumps/', args['tmpcode'], '_xx.csv'),
#     stringsAsFactors=FALSE)
# write_feather(z, paste0('../spdumps/', args['tmpcode'], '_xx.feather'))
origdf = read_feather(paste0('../spdumps/', args['tmpcode'], '_xx.feather'))
pldf = select(origdf, DateTime_UTC, everything()) %>%
    mutate(DateTime_UTC=as.POSIXct(DateTime_UTC, tz='UTC')) %>%
    as.data.frame()

#create df of same structure as data, to hold flag information
flagdf = pldf
flagdf[, 2:(ncol(flagdf) - 1)] = 0

#trim data before processing; datetime and upload id will be reattached at end
dtcol = pldf$DateTime_UTC
upload_id = pldf$upload_id
pldf$DateTime_UTC = NULL
pldf$upload_id = NULL

# impute gaps, ignoring series that are 95% gap or more
pldf = as.data.frame(apply(pldf, 2,
    function(x){
        if(sum(is.na(x)) / length(x) > 0.95) return(x)
        imputeTS::na_interpolation(x, option='linear')
    }))

#operation 1: simple range checker
#flags anything that's physically impossible with code 1
df_and_flagcodes = range_check(pldf, flagdf)
pldf = df_and_flagcodes$df
flagdf = df_and_flagcodes$flagdf

#operation 2: residual error based outlier detection via anomalize package
#flags outliers with code 2
df_and_flagcodes = basic_outlier_detect(pldf, flagdf)
pldf = df_and_flagcodes$df
flagdf = df_and_flagcodes$flagdf

#save flag codes, cleaned data to be read by flask when user follows email link
write_feather(pldf, paste0('../spdumps/', args['tmpcode'], '_cleaned.feather'))
write_feather(flagdf, paste0('../spdumps/', args['tmpcode'], '_flags.feather'))

#notify user that pipeline processing is complete
system2('/home/mike/miniconda3/envs/python2/bin/python',
# system2('/home/aaron/sp/spenv/bin/python',
    args=c('pipeline/notify_user.py', args))
