library(plyr)
library(tidyverse)
library(imputeTS)
library(feather)
library(lubridate)
rm(list=ls()); cat('/014')                                  ####

#NOTE:
#linear interpolator now marks imputations with code 1
#ICI imputer uses code 2

#setwd('/home/aaron/sp')                                  ####
setwd('/home/mike/git/streampulse/server_copy/sp')

source('pipeline/helpers.R')

#retrieve arguments passed from app.py
# args = commandArgs(trailingOnly=TRUE)                                  ####
# names(args) = c('notificationEmail', 'tmpcode', 'region', 'site',
#     'interpdeluxe')
args = list('tmpcode'='e5b659a48490', 'interpdeluxe'='false')
usr_msgs = list()

#read in datasets written by main pipeline
origdf = read_feather(paste0('../spdumps/', args['tmpcode'], '_orig.feather'))
pldf = read_feather(paste0('../spdumps/', args['tmpcode'],
    # '_cleaned_checked.feather'))                              ####
    '_cleaned.feather'))
pldf = select(pldf, -DateTime_UTC, -upload_id)
# flagdf = read_feather(paste0('../spdumps/', args['tmpcode'], '_flags.feather'))
# flagdf = select(flagdf, -DateTime_UTC)

#determine the sampling interval
samp_int_m = determine_sample_interval(origdf)
#and fill in any missing records
# origdf = populate_missing_rows(origdf, samp_int_m)

#keep track of NAs; make a new df for storing flag codes
na_inds = lapply(pldf, function(x) which(is.na(x)))
flagdf = pldf
flagdf[,] = 0

#pl operation 4: again linearly interpolate gaps <= 3 hours
pldf = lin_interp_gaps(pldf, samp_int=samp_int_m, gap_thresh=180)

#assign qaqc code 1 to imputed gaps that weren't introduced by the pipeline
for(c in colnames(pldf)){
    interp_inds = na_inds[[c]][which(! is.na(pldf[na_inds[[c]], c]))]
    flagdf[interp_inds, c] = flagdf[interp_inds, c] + 1
}

#pl operation 5: Imputation by Correlative Inference
if(args$interpdeluxe == 'true'){
    na_inds = lapply(pldf, function(x) which(is.na(x)))
    pldf = ici(pldf, interv=samp_int_m)

    #assign qaqc code 2 to gaps filled by ICI
    for(c in colnames(pldf)){
        interp_inds = na_inds[[c]][which(! is.na(pldf[na_inds[[c]], c]))]
        flagdf[interp_inds, c] = flagdf[interp_inds, c] + 2
    }
}

#remove entirely empty rows
rm_rows = which(apply(pldf, 1, function(x) all(is.na(x))))
if(length(rm_rows)){
    pldf = pldf[-rm_rows, ]
    origdf = origdf[-rm_rows, ]
    flagdf = flagdf[-rm_rows, ]
}

#save flag codes, cleaned data to be read in by flask controllers
pldf = dplyr::bind_cols(list('DateTime_UTC'=origdf$DateTime_UTC),
    pldf, list('upload_id'=origdf$upload_id))
flagdf$DateTime_UTC = origdf$DateTime_UTC
##PROBS DONT NEED TO RESAVE ORIG
write_feather(origdf, paste0('../spdumps/', args['tmpcode'], '_orig.feather'))
write_feather(pldf, paste0('../spdumps/', args['tmpcode'], '_cleaned_checked_imp.feather'))
write_feather(flagdf, paste0('../spdumps/', args['tmpcode'], '_flags2.feather'))

#notify user that pipeline processing is complete
system2('/home/mike/miniconda3/envs/python2/bin/python',
#system2('/home/aaron/miniconda3/envs/sp/bin/python',
    args=c('pipeline/notify_user.py', args))

message('end of pipeline.R')