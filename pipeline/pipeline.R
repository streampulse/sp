library(tidyverse)
library(imputeTS)
library(anomalize)
library(feather)
library(lubridate)

#NOTE:
#range checker marks anomalies with code 1
#outlier detectors mark anomalies with code 2
#gap fillers mark imputations, not including those following anomaly removal,
    #with code 4

#setwd('/home/aaron/sp')
setwd('/home/mike/git/streampulse/server_copy/sp')

source('pipeline/helpers.R')
find_outliers = readChar('find_outliers.R', file.info('find_outliers.R')$size)
find_outliers = eval(parse(text=find_outliers))

#retrieve arguments passed from app.py
args = commandArgs(trailingOnly=TRUE)
names(args) = c('notificationEmail', 'tmpcode', 'region', 'site')
# args = list('tmpcode'='e5b659a48490')

#read in dataset saved during first part of upload process
#origdf = read_csv(paste0('../spdumps/', args['tmpcode'], '_xx.csv'),
#    guess_max=10000) %>%
origdf = read_feather(paste0('../spdumps/', args['tmpcode'], '_xx.feather')) %>%
    mutate(DateTime_UTC=force_tz(as.POSIXct(DateTime_UTC), 'UTC'))

#determine the sampling interval and fill in any missing records
samp_int_m = determine_sample_interval(origdf)
origdf = populate_missing_rows(origdf, samp_int_m)

#copy and trim df for pipeline traversal
pldf = select(origdf, -DateTime_UTC, -upload_id)

#trim data before processing; datetime and upload id will be reattached at end
# pldf$DateTime_UTC = NULL
# pldf$upload_id = NULL

#keep track of NAs; create df for storing flag codes
na_inds = lapply(pldf, function(x) which(is.na(x)))
flagdf = pldf
flagdf[,] = 0

#pl operation 1: simple range checker
#flags physically impossible values with code 1
df_and_flagcodes = range_check(pldf, flagdf)
pldf = df_and_flagcodes$d
pldf = lin_interp_gaps(pldf) #operation 2 requires gapless series
flagdf = df_and_flagcodes$flagd

#pl operation 2: residual error based outlier detection via anomalize package
#flags outliers with code 2
df_and_flagcodes = basic_outlier_detect(pldf, flagdf, origdf$DateTime_UTC)
pldf = df_and_flagcodes$d
flagdf = df_and_flagcodes$flagd
# testplot(pldf, xmin='2019-12-27', xmax='2019-12-28',
#     ylims=c(1, 2.3), showpoints=T)

#pl operation 3: restore NAs and do some imputation
for(c in colnames(pldf)){
    pldf[na_inds[[c]], c] = NA
}
pldf = lin_interp_gaps(pldf, samp_int=samp_int_m, gap_thresh=180)

#assign qaqc code 4 to imputed gaps that weren't introduced by the detectors
for(c in colnames(pldf)){
    interp_inds = na_inds[[c]][which(! is.na(pldf[na_inds[[c]], c]))]
    flagdf[interp_inds, c] = flagdf[interp_inds, c] + 4
}

#remove entirely empty rows
rm_rows = which(apply(pldf, 1, function(x) all(is.na(x))))
# rmrowfile = paste0('../spdumps/', args['tmpcode'], '_rmrows1.csv')
# write.csv(data.frame(x=rm_rows), rmrowfile, row.names=FALSE)
if(length(rm_rows)){
    pldf = pldf[-rm_rows, , drop=FALSE]
    origdf = origdf[-rm_rows, , drop=FALSE]
    flagdf = flagdf[-rm_rows, , drop=FALSE]
}

#save flag codes, cleaned data to be read by flask controllers when
#user follows email link
pldf = dplyr::bind_cols(list('DateTime_UTC'=origdf$DateTime_UTC),
    pldf, list('upload_id'=origdf$upload_id))
flagdf$DateTime_UTC = origdf$DateTime_UTC
write_feather(origdf, paste0('../spdumps/', args['tmpcode'], '_orig.feather'))
write_feather(pldf, paste0('../spdumps/', args['tmpcode'], '_cleaned.feather'))
write_feather(flagdf, paste0('../spdumps/', args['tmpcode'], '_flags.feather'))
#write.csv(origdf, paste0('../spdumps/', args['tmpcode'], '_orig.csv'), row.names=FALSE)
#write.csv(pldf, paste0('../spdumps/', args['tmpcode'], '_cleaned.csv'), row.names=FALSE)
#write.csv(flagdf, paste0('../spdumps/', args['tmpcode'], '_flags.csv'), row.names=FALSE)

#notify user that pipeline processing is complete
system2('/home/mike/miniconda3/envs/python2/bin/python',
#system2('/home/aaron/miniconda3/envs/sp/bin/python',
    args=c('pipeline/notify_user.py', args))

message('end of pipeline.R')
