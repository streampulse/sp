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
# args = list('tmpcode'='5c80e0190222', 'interpdeluxe'='false')

#read in datasets written by main pipeline
# origdf = read_csv(paste0('../spdumps/', args['tmpcode'], '_orig.csv'))
# pldf = read_csv(paste0('../spdumps/', args['tmpcode'], '_cleaned.csv'))
origdf = read_feather(paste0('../spdumps/', args['tmpcode'], '_orig.feather'))
pldf = read_feather(paste0('../spdumps/', args['tmpcode'],
    '_cleaned_checked.feather'))                              ####
pldf = as_tibble(pldf) %>%
    select(-DateTime_UTC, -upload_id) %>%
    bind_cols(select(origdf, DateTime_UTC)) %>%
    arrange(DateTime_UTC) %>%
    group_by(DateTime_UTC) %>%
    summarize_all(mean, na.rm=TRUE) %>%
    ungroup()

# flagdf = read_feather(paste0('../spdumps/', args['tmpcode'], '_flags.feather'))
# flagdf = select(flagdf, -DateTime_UTC)

#fill in any missing records
samp_int_m = determine_sample_interval(pldf)
pldf = populate_missing_rows(pldf, samp_int_m)
dtcol = pldf$DateTime_UTC
pldf$DateTime_UTC = NULL

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

na_inds = lapply(pldf, function(x) which(is.na(x)))
pldf = bind_cols(list('DateTime_UTC'=dtcol), pldf)

#pl operation 5: Nearest Days Interpolation
if(args['interpdeluxe'] == 'true'){

    ndiout = tryCatch(NDI(pldf, interv=samp_int_m),
        error=function(e){
            usr_msg_code <<- '3'
            return('err') #if all errors have "error" class, just return e
        })

    if(! (length(ndiout) == 1 && ndiout == 'err') ){

        #assign qaqc code 2 to any gaps filled by NDI
        dfcols = colnames(ndiout)
        for(c in dfcols[dfcols != 'DateTime_UTC']){
            interp_inds = na_inds[[c]][which(! is.na(ndiout[na_inds[[c]], c]))]
            flagdf[interp_inds, c] = flagdf[interp_inds, c] + 2
        }

        snap_days(ndiout)
        plot(ndiout$AirPres_kPa, col='red', type='l')
        lines(pldf$AirPres_kPa)

        for(c in dfcols[dfcols != 'DateTime_UTC']){
            twos = which(flagdf[[c]] == 2)
            if(length(twos)){
                ndi_sections = ndiout[twos, c('DateTime_UTC', c)]
                ndi_rounded_dates = round(ndi_sections$DateTime_UTC, 'hour')
                daystarts = which(substr(ndi_rounded_dates, 12, 19) ==
                    '00:00:00')
                r = rle(diff(daystarts))
                ends = cumsum(r$lengths)
                r = cbind(values=r$values,
                    starts=c(1, ends[-length(ends)] + 1),
                    stops=ends, lengths=r$lengths, deparse.level=1)
                r = r[r[, 'values'] == 1, , drop=FALSE]
                r = r[-nrow(r), , drop=FALSE]
                ds_fac = cut(1:length(daystarts), c(0, r[, 'stops'] + 1, Inf))
                daystart_list = split(daystarts, ds_fac)
                daystarts = unname(lapply(daystart_list, find_snappoints, twos,
                    samp_int_m))

                midday_bounds =
                    #make sure bounds don't exceed time range

                for(j in 1:length(daystarts)){
                    prejump = daystarts[j] - 1
                    jump = daystarts[j]


                    ndiout[c(prejump, jump), c]
                }
            }
        }
        pldf = ndiout

    # } else {
    #     pldf = bind_cols(list('DateTime_UTC'=dtcol), pldf)
    }


}

#remove entirely empty rows
# rm_rows = which(apply(pldf, 1,
rm_rows = which(apply(select(pldf, -DateTime_UTC), 1,
    function(x) all(is.na(x)) ))
if(length(rm_rows)){
    pldf = pldf[-rm_rows, ]
    # origdf = origdf[-rm_rows, ]
    flagdf = flagdf[-rm_rows, ]
}

#save flag codes, imputed dataset to be read in by flask controllers
flagdf$DateTime_UTC = pldf$DateTime_UTC
pldf$upload_id = rep(origdf$upload_id[1], nrow(pldf))
write_feather(pldf, paste0('../spdumps/', args['tmpcode'],
    '_cleaned_checked_imp.feather'))
write_feather(flagdf, paste0('../spdumps/', args['tmpcode'], '_flags2.feather'))

# #notify user that pipeline processing is complete
# system2('/home/mike/miniconda3/envs/python2/bin/python',
# #system2('/home/aaron/miniconda3/envs/sp/bin/python',
#     args=c('pipeline/notify_user.py', args))

writeLines(usr_msg_code, sep='',
    con=paste0('../spdumps/', args['tmpcode'], '_usrmsg.txt'))

message('end of fill_remaining_gaps.R')
