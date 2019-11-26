library(tidyverse)
library(imputeTS)
library(anomalize)
library(feather)
library(lubridate)

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
# args = list('tmpcode'='8461a107c644')
origdf = read_feather(paste0('../spdumps/', args['tmpcode'], '_xx.feather')) %>%
    mutate(DateTime_UTC=force_tz(as.POSIXct(DateTime_UTC), 'UTC'))

#determine the sampling interval and fill in any missing records
samp_int_m = determine_sample_interval(origdf)
origdf = populate_missing_rows(origdf, samp_int_m)

#copy and trim df for pipeline traversal
pldf = select(origdf, -DateTime_UTC, -upload_id)
# pldf = select(origdf, DateTime_UTC, everything(), -upload_id) %>%
    # as.data.frame()

#trim data before processing; datetime and upload id will be reattached at end
# pldf$DateTime_UTC = NULL
# pldf$upload_id = NULL

#keep track of NAs; create df for storing flag codes
na_inds = which(is.na(pldf))
flagdf = pldf
flagdf[,] = 0

# pldf$pH[20:30] = NA
# pldf$SpecCond_uScm[10:30] = NA
# pldf$WaterTemp_C[20] = NA

#operation 1: simple range checker
#flags physically impossible values with code 1
df_and_flagcodes = range_check(pldf, flagdf)
pldf = df_and_flagcodes$d
pldf = lin_interp_gaps(pldf, flagdf)
flagdf = df_and_flagcodes$flagd

#operation 2: residual error based outlier detection via anomalize package
#flags outliers with code 2
df_and_flagcodes = basic_outlier_detect(pldf, flagdf, origdf$DateTime_UTC)
pldf = df_and_flagcodes$d
pldf = dplyr::bind_cols(list('DateTime_UTC'=origdf$DateTime_UTC),
    pldf, list('upload_id'=origdf$upload_id))
flagdf = df_and_flagcodes$flagd

#operation 3: linearly interpolate gaps <= 3 hours


#save flag codes, cleaned data to be read by flask when user follows email link
flagdf$DateTime_UTC = origdf$DateTime_UTC
write_feather(pldf, paste0('../spdumps/', args['tmpcode'], '_cleaned.feather'))
write_feather(flagdf, paste0('../spdumps/', args['tmpcode'], '_flags.feather'))

#notify user that pipeline processing is complete
system2('/home/mike/miniconda3/envs/python2/bin/python',
# system2('/home/aaron/sp/spenv/bin/python',
    args=c('pipeline/notify_user.py', args))
