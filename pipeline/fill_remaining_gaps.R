library(plyr)
library(tidyverse)
library(imputeTS)
library(feather)
library(lubridate)
rm(list=ls()); cat('/014')                                  ####

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
# args = list('tmpcode'='098031a2d560', 'interpdeluxe'='false')

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

        # snap_days(ndiout)
        plot(ndiout$DateTime_UTC, ndiout$AirPres_kPa, col='red', type='l', lwd=2)
        lines(pldf$DateTime_UTC, pldf$AirPres_kPa, lwd=2)

        # c='AirPres_kPa'
        for(c in dfcols[dfcols != 'DateTime_UTC']){
            twos = which(flagdf[[c]] == 2)
            # r = rle_custom(diff(as.numeric(twodates)))
            # r = r[r[, 'values'] == 900, , drop=FALSE]
            # twos[r[, 'stops']]
            # twodates[r[, 'stops']]

            # if(nrow(r) > 1){
            #     for(i in nrow(r):2){
            #         skipped_day = r[i, 'starts'] - r[i - 1, 'stops'] == 2
            #         if(skipped_day){
            #             #logic here is close. filter rows of r if they represent
            #             #skipped days. only snap contiguous days.
            #             #thinking i need to split ndi_sections into a list in
            #             #order to determine bounds.
            #             #on the other hand, maybe i already have them right here.
            #             #the starts and stops...
            #
            # r = r[-nrow(r), , drop=FALSE]
            # ds_fac = cut(1:length(daystarts), c(0, r[, 'stops'] + 1, Inf))
            # daystart_list = split(daystarts, ds_fac)

            if(length(twos)){
                twodates = ndiout$DateTime_UTC[twos]
                ndi_sections = ndiout[twos, c('DateTime_UTC', c)]
                points(ndi_sections$DateTime_UTC, ndi_sections$AirPres_kPa,
                    col='blue', cex=0.5, pch=20)
                ndi_rounded_dates = round(ndi_sections$DateTime_UTC, 'hour')
                daystarts = which(substr(ndi_rounded_dates, 12, 19) ==
                    '00:00:00')
                r = rle_custom(diff(daystarts))
                r = r[r[, 'values'] == 1, , drop=FALSE]
                if(nrow(r) > 1){
                    r = r[-nrow(r), , drop=FALSE]
                }
                ds_fac = cut(1:length(daystarts), c(0, r[, 'stops'] + 1, Inf))
                ndi_ind_list = split(daystarts, ds_fac, drop=TRUE)
                ndi_list = unname(lapply(ndi_ind_list,
                    find_snappoints, twos, twodates, samp_int_m))
                ndi_list = Filter(function(x) ! is.null(x), ndi_list)

                if(! length(ndi_list)){
                    # usr_msg_code <<- '4'
                    return(flow control here; no message needed (day skipped))
                }
                # contiguous_days = function(x){
                #     x$daystart
                # }
                # sapply(daystarts, contiguous_days, samp_int_m)


                ndi_edges = rle_custom(flagdf[[c]] == 2)
                ndi_edges = ndi_edges[ndi_edges[, 'values'] == 1, ]
                na_edges = rle_custom(is.na(pldf[[c]]))
                na_edges = na_edges[na_edges[, 'values'] == 1, ]
                # na_edges = alply(na_edges, 1, function(x) x[2:3] )
                #identify contiguous-day (1 or 2 days only) NDI sections.
                #these and these only need to be edge-snapped
                for(j in nrow(ndi_edges):1){
                    gapless_ndi = paste(ndi_edges[j, 'starts'],
                            ndi_edges[j, 'stops']) %in%
                        paste(na_edges[, 'starts'], na_edges[, 'stops'])
                    if(! gapless_ndi) ndi_edges = ndi_edges[-j, , drop=FALSE]
                    # Position(function(x){
                    #     ndi_edges[j, 'starts'] <= x[1] &&
                    #         ndi_edges[j, 'stops'] >= x[2]
                    # }, na_edges, right=TRUE)
                }
                if(nrow(ndi_edges)){
                    ndi_edges = alply(ndi_edges, 1, function(x){
                        list(matrix(x, nrow=1))
                    })
                    ds_db_lined_up = all(mapply(function(x, y){
                        x$daystart >= y[[1]][2] && x$daystart <= y[[1]][3]
                    }, ndi_list, ndi_edges))
                    if(! ds_db_lined_up){
                        usr_msg_code <<- '5' #handle 4 and 5
                        return()
                        #need flow control here
                    }
                    ndi_list = mapply(function(x, y){
                        x$bounds = y[[1]][2:3]
                        return(x)
                    }, ndi_list, ndi_edges, SIMPLIFY=FALSE)

                } else {
                    # usr_msg_code <<- '6'
                    return(no snapping or code needed)
                }

                for(j in 1:length(ndi_list)){

                    ndi_section = ndi_list[[j]]
                    ds = ndi_section$daystart
                    lb = ndi_section$bounds[1]
                    rb = ndi_section$bounds[2]

                    snapdist = diff(ndiout[(ds - 1):ds, c])
                    ndilen = rb - lb + 1
                    # ndiout[lb:ds,c, drop=T]
                    # ndiout[ds:rb,c, drop=T]
                    ndilen_l = ds - lb
                    ndilen_r = rb - ds + 1
                    snapprop_l = ndilen_l / ndilen
                    snapprop_r = 1 - snapprop_l
                    snapshift_l = seq(0, snapdist * snapprop_l,
                        length.out=ndilen_l)
                    snapshift_r = seq(-1 * snapdist * snapprop_r, 0,
                        length.out=ndilen_r)

                    ndiout[lb:(ds - 1), c] = ndiout[lb:(ds - 1), c] + snapshift_l
                    ndiout[ds:rb, c] = ndiout[ds:rb, c] + snapshift_r

                    plot(ndiout$DateTime_UTC, ndiout$AirPres_kPa, col='red', type='l')
                    lines(pldf$DateTime_UTC, pldf$AirPres_kPa)
                    # ndiout[(ds - 3):(ds + 3), c, drop=TRUE]

                    # flagdf[twos[daystarts[j]], c]
                    # c(twos[1], twos[length(twos)])
                    # Find(function(x){ })
                    # prejump = daystarts[j] - 1
                    # jump = daystarts[j]

                    # ndiout[c(prejump, jump), c]
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
