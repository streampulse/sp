function(df){

    #read in r packages
    library(imputeTS)
    library(plotrix)
    library(accelerometry)

    #remove date/time cols
    df = df[,-which(names(df) %in% c("DateTime_UTC","date"))]

    outlier_list = list()

    #loop through each variable
    for(col in 1:ncol(df)){

        #if data series is >98% empty, skip it
        NA_prop = mean(is.na(df[,col]))
        if(NA_prop > 0.98 | df[1,col] == 'None'){
            outlier_list[[col]] = 'NONE'
            names(outlier_list)[col] = colnames(df)[col]
            next
        }

        #convert to time series
        tm = ts(df[,col], deltat = 1/96)

        #locate gobal outliers (>4sd beyond the mean)
        ts_u = mean(tm, na.rm=TRUE)
        ts_sd = sd(tm, na.rm=TRUE)
        big_outliers_h = which(tm > ts_u + (4*ts_sd))
        big_outliers_l = which(tm < ts_u - (4*ts_sd))
        big_outliers = unique(c(big_outliers_h, big_outliers_l))

        #interpolate NAs (could work around this without much hassle)
        tm = na.seadec(tm, algorithm='interpolation')

        #get diffs in value between each time point and the next
        diffs = diff(tm)

        #get mean and sd of diffs (large ones are ater referred to as "jumps")
        u = mean(diffs, na.rm=TRUE)
        sd = sd(diffs, na.rm=TRUE)

        #expand sd threshold until <3% of diffs are outside sd bounds
        #these are now potential outliers in addition to the globals above
        sd_scaler = 1.8
        big_jump_prop = Inf
        while(big_jump_prop > 0.03){
            sd_scaler = sd_scaler + 0.2
            big_jump_prop = sum(diffs > sd_scaler * sd) / length(diffs)
        }

        #get indices of large jumps between successive points
        pos_jumps = which(diffs > sd_scaler * sd)
        neg_jumps = which(diffs < -sd_scaler * sd)
        jump_inds = sort(c(pos_jumps, neg_jumps))

        #if there are no such jumps to speak of, grab global outliers
        #(or nothing) and move on
        if(length(pos_jumps) == 0 | length(neg_jumps) == 0){ 
            if(length(big_outliers)){
                outlier_list[[col]] = big_outliers
            } else { 
                outlier_list[[col]] = 'NONE'
            }
            names(outlier_list)[col] = colnames(df)[col]
            next
        }

        #an outlier as defined here must consist of a pair of positive and
        #negative jumps. here we get the run lengths of consecutive positive
        #(1) and negative (0) jumps
        runs = rle2(as.numeric(jump_inds %in% pos_jumps), indices=TRUE)
        lr = runs[,'lengths'] > 3 #runs > 3 are considered "long"
        long_runs = runs[lr, 2:3, drop=FALSE]

        #and then decide which ones to "keep", i.e. which ones may be actual
        #outliers
        keep = numeric()
        if(length(long_runs)){
            for(i in 1:nrow(long_runs)){
                r = long_runs[i,]

                #get the indices of the first and second jumps in the run,
                #and also the last and second-to-last
                j = jump_inds[unique(c(r[1], r[1] + 1, r[2] - 1, r[2]))]

                #if both pairs' values are quite close to each other in time,
                #assume this is one long run of related jumps
                if(abs(j[2]-j[1]) < 8 & abs(j[length(j)]-j[length(j)-1]) < 8){
                    next
                }

                #otherwise it's a long run on one side (probably a real data
                #feature) and a true potential outlier on the other side.

                #find out which side of the run has the shorter time interval
                #between adjacent jumps and assume that side does not contain
                #the potential outlier
                t = time(tm)[j + 1] #+1 to convert from diff inds to ts inds
                left_jump_interv = t[2] - t[1]
                right_jump_interv = t[length(t)] - t[length(t)-1]
                not_outlier = which.min(c(left_jump_interv, right_jump_interv))

                #store the index of the other side of the run
                keep = append(keep, i[-not_outlier])
            }
        }

        #all remaining inds may represent alternating pos/neg jumps
        posNeg_jump_pairs = sort(unique(c(keep, as.vector(runs[!lr,2:3]))))
        outlier_inds = jump_inds[posNeg_jump_pairs]

        #winnow them down using various heuristics
        n_outlier_pieces = Inf #an outlier piece is one unidirectional jump
        counter = 0 #dont loop for too long
        if(length(outlier_inds) == 1){
            outlier_ts = 'NONE' #if only one ind, can't be an alternating jump
        } else {
            while(length(outlier_inds) > 1 &
                    n_outlier_pieces > 50 & counter < 6){

                outdif = diff(outlier_inds)
                rm_multjump = rm_oneway = NULL

                #here jump refers to the gap between potential outlier indices
                short_jumps = outdif < 15

                #***if the first gap is long, assume the first outlier piece
                #is a component of a data feature that got cut off by the border
                #of the time window, (which will cause a "frameshift mutation"
                #downstream, so remove it
                if(!short_jumps[1]){
                    outlier_inds = outlier_inds[-1]
                    counter = counter + 1
                    next
                }

                #a multijump is a series of jumps in the same direction wihtin
                #a short space of time. not likely to be a real outlier
                jump_runs = rle2(as.numeric(short_jumps), indices=TRUE,
                    return.list=FALSE)
                multijumps = jump_runs[jump_runs[,'lengths'] > 1,
                    2:3, drop=FALSE]
                if(length(multijumps)){

                    #filter jumps with long gaps between
                    multijumps = multijumps[short_jumps[multijumps[,'starts']],,
                        drop=FALSE]

                    #interpolate indices within multijumps that do not
                    #themselves represent jumps
                    seq_list = mapply(function(x, y){ seq(x, y+1, 1) },
                        multijumps[,1], multijumps[,2],
                        SIMPLIFY=FALSE)

                    #these are the indices of mutijumps, which will be removed
                    rm_multjump = unlist(seq_list)
                }

                #this works just like the *** comment above, but on the tail
                #of the series. sorry for the lack of naming consistency here.
                big_outdif = outdif > 15
                if(big_outdif[length(big_outdif)]){
                    outlier_inds = outlier_inds[-length(outlier_inds)]
                    counter = counter + 1
                    next
                }

                #if none of the outier pieces are near each other, there can be
                #no pos/neg pairs, so assume no outliers
                if(all(big_outdif)){
                    outlier_ts = 'NONE'
                    break
                } else {

                    #find remaining one-way jumps
                    same_sign_runs = rle2(as.numeric(big_outdif), indices=TRUE,
                        return.list=TRUE)

                    if(length(same_sign_runs)){
                        l = same_sign_runs$lengths
                        one_way_jumps = numeric()
                        for(i in 1:length(l)){
                            if(l[i] > 1){
                                s = same_sign_runs$starts[i]
                                one_way_jumps = append(one_way_jumps,
                                    seq(s, s + (l[i] - 2), 1))
                            }
                        }
                    }

                    #just a bit of hacky filtering to isolate the one-way jumps
                    if(length(one_way_jumps)){
                        one_way_jumps = one_way_jumps[big_outdif[one_way_jumps]]
                        outdif_filt = outdif
                        outdif_filt[-one_way_jumps] = 0
                        rm_oneway = which(outdif_filt > 0) + 1
                    }
                }
                removals = unique(c(rm_multjump, rm_oneway))
                if(!is.null(removals)){
                    outlier_inds = outlier_inds[-removals]
                }

                #if there's an even number of outlier pieces remaining,
                #interpolate between the members of each pos/neg pair and
                #contribute to list of outlier components to be identified
                #for flagging in qa/qc
                if(length(outlier_inds) %% 2 == 0){
                    outlier_inds = matrix(outlier_inds, ncol=2, byrow=TRUE)
                    seq_list = mapply(function(x, y){ seq(x+1, y, 1) },
                        outlier_inds[,1], outlier_inds[,2],
                        SIMPLIFY=FALSE)
                    outlier_ts = unlist(seq_list)

                #otherwise get rid of the least extreme outlier piece
                } else {
                    smallest_diff = which.min(abs(diffs[outlier_inds]))
                    outlier_inds = outlier_inds[-smallest_diff]
                    counter = counter + 1
                    next
                }
                n_outlier_pieces = length(outlier_ts)
                counter = counter + 1
            }
        }

        #if the while loop completes and there are still tons of pieces,
        #assume there was a frameshift or something and abort.
        #the bit about outlier_ts existing is for compatibility once this R
        #code gets translated to python (which can't handle R's NULL)
        if(n_outlier_pieces > 50 || !exists('outlier_ts') ||
            is.null(outlier_ts)){ #deal with R-py null value mismatch
            outlier_ts = 'NONE'
        }

        #bring in the global outliers from above
        if(outlier_ts == 'NONE'){
            if(length(big_outliers)){
                outlier_ts = unique(big_outliers)
            } else {
                outlier_ts = 'NONE'
            }
        } else {
            outlier_ts = unique(c(outlier_ts, big_outliers))
        }
        outlier_list[[col]] = outlier_ts
        names(outlier_list)[col] = colnames(df)[col]
    }

    # print(outlier_list)
    return(outlier_list)
}

