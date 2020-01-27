library(plyr)
library(tidyverse)
library(imputeTS)
library(feather)
library(lubridate)
# rm(list=ls()); cat('/014')                                  ####

#NOTE:
#linear interpolator now marks imputations with code 1
#NDI imputer uses code 2

#setwd('/home/aaron/sp')                                  ####
setwd('/home/mike/git/streampulse/server_copy/sp')

source('pipeline/helpers.R')
source('pipeline/helpers_ndi.R')
usr_msg_code = '0'

#retrieve arguments passed from app.py
args = commandArgs(trailingOnly=TRUE)                                  ####
names(args) = c('tmpcode', 'interpdeluxe')
# args = list('tmpcode'='2b2c89ed5452', 'interpdeluxe'='false')

#read in datasets written by main pipeline
# origdf = read_csv(paste0('../spdumps/', args['tmpcode'], '_orig.csv'))
# pldf = read_csv(paste0('../spdumps/', args['tmpcode'], '_cleaned.csv'))
origdf = read_feather(paste0('../spdumps/', args['tmpcode'], '_orig.feather'))
pldf = read_feather(paste0('../spdumps/', args['tmpcode'],
    '_cleaned_checked.feather'))                              ####
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

#pl operation 5: Nearest Days Interpolation
if(args['interpdeluxe'] == 'true'){
    na_inds = lapply(pldf, function(x) which(is.na(x)))
    ndiout = tryCatch(NDI(pldf, interv=samp_int_m),
        error=function(e){
            usr_msg_code <<- '3'
            return('err') #if all errors have "error" class, just return e
        })
    if(! (length(ndiout) == 1 && ndiout == 'err') ){
        pldf = ndiout
    }

    #assign qaqc code 2 to any gaps filled by NDI
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

#save flag codes, imputed dataset to be read in by flask controllers
pldf = dplyr::bind_cols(list('DateTime_UTC'=origdf$DateTime_UTC),
    pldf, list('upload_id'=origdf$upload_id))
flagdf$DateTime_UTC = origdf$DateTime_UTC
write_feather(pldf, paste0('../spdumps/', args['tmpcode'], '_cleaned_checked_imp.feather'))
write_feather(flagdf, paste0('../spdumps/', args['tmpcode'], '_flags2.feather'))

# #notify user that pipeline processing is complete
# system2('/home/mike/miniconda3/envs/python2/bin/python',
# #system2('/home/aaron/miniconda3/envs/sp/bin/python',
#     args=c('pipeline/notify_user.py', args))

writeLines(usr_msg_code, sep='',
    con=paste0('../spdumps/', args['tmpcode'], '_usrmsg.txt'))

message('end of fill_remaining_gaps.R')
