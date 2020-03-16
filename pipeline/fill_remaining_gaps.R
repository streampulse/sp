library(plyr)
library(tidyverse)
library(imputeTS)
library(feather)
library(lubridate)
# rm(list=ls()); cat('/014')                                  ####

# NOTE:
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
# args = list('tmpcode'='3750a8854434', 'interpdeluxe'='false')
# args = list('tmpcode'='539b05f6f61d', 'interpdeluxe'='false')

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
    # plot(ndiout$DateTime_UTC, ndiout$WaterTemp_C, col='red', type='l')
    # lines(pldf$DateTime_UTC, pldf$WaterTemp_C)

    if(! (length(ndiout) == 1 && ndiout == 'err') ){

        #assign qaqc code 2 to any gaps filled by NDI
        dfcols = colnames(ndiout)
        for(c in dfcols[dfcols != 'DateTime_UTC']){
            interp_inds = na_inds[[c]][which(! is.na(ndiout[na_inds[[c]], c]))]
            flagdf[interp_inds, c] = flagdf[interp_inds, c] + 2
        }

        # par(mfrow=c(4, 2), mar=c(0,0,0,0), oma=c(0,0,0,0))
        # for(dfc in dfcols[-1]){
        #     plot(ndiout$DateTime_UTC, ndiout[,dfc], col='orange', type='l', lwd=2)
        #     lines(pldf$DateTime_UTC, pldf[, dfc, drop=TRUE], lwd=2)
        #     abline(v=pldf$DateTime_UTC[substr(pldf$DateTime_UTC, 12, 19) == '00:00:00'],
        #         lty=3, col='gray30')
        #     mtext(dfc, 3, line=-4)
        # }

        # par(mfrow=c(1,1), mar=c(4,4,4,4))
        # plot(ndiout$DateTime_UTC, ndiout[[c]], col='orange', type='l', lwd=2)
        # lines(pldf$DateTime_UTC, pldf[[c]], lwd=2)
        # # abline(v=pldf$DateTime_UTC[substr(pldf$DateTime_UTC, 12, 19) == '00:00:00'],
        # #     lty=3, col='gray30')
        # # for(i in 1:nrow(fullday_skips)){
        # for(i in 1:2){
        #     abline(v=pldf$DateTime_UTC[fullday_skips[i,2:3]], col='gray')
        #     print(paste0(i, ': ', fullday_skips[i,2], '-', fullday_skips[i,3],
        #         '; ', fullday_skips[i,3] - fullday_skips[i,2]))
        #     # readline()
        # }
        # # abline(v=pldf$DateTime_UTC[fullday_skips[,2]], col='gray')
        #
        # xlims = as.numeric(as.POSIXct(c('2006-10-04', '2007-1-06')))
        # plot(ndiout$DateTime_UTC, ndiout[[c]], col='orange', type='l',
        #     lwd=2, xlim=xlims)
        # lines(pldf$DateTime_UTC, pldf[[c]], lwd=2)
        # abline(v=pldf$DateTime_UTC[substr(pldf$DateTime_UTC, 12, 19) == '00:00:00'],
        #     lty=3, col='gray30')
        # for(i in 1:2){
        #     abline(v=pldf$DateTime_UTC[fullday_skips[i,2:3]], col='gray')
        #     print(paste0(i, ': ', fullday_skips[i,2], '-', fullday_skips[i,3],
        #         '; ', fullday_skips[i,3] - fullday_skips[i,2]))
        # }

        # plot(ndiout$DateTime_UTC, ndiout$AirPres_kPa, col='orange', type='l',
        #     lwd=2, ylim=c(14.84, 14.9))
        # lines(pldf$DateTime_UTC, pldf$AirPres_kPa, lwd=2)
        ndiout = tryCatch(snap_days(dfcols, flagdf, ndiout, pldf,
                interv=samp_int_m),
            error=function(e){
                return('err')
            })

        # lines(ndiout$DateTime_UTC, ndiout[[c]], col='red')
        # lines(pldf$DateTime_UTC, pldf[[c]])

        if(length(ndiout) == 1 && ndiout == 'err'){
            usr_msg_code <<- '4' #unknown error
        } else if(length(ndiout) == 1 && ndiout == 'no action needed'){
            usr_msg_code <<- '5'
        } else {
            pldf = ndiout
        }

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
